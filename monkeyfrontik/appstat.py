import functools
import logging
import tornado.httpclient
import tornado.web
import tornado.wsgi
import warnings
import time
from lxml import etree

import contextlib
from functools import partial, wraps

with warnings.catch_warnings():
    warnings.simplefilter('ignore', DeprecationWarning)
    from google.appengine.ext.appstats import recording
from tornado.curl_httpclient import CurlAsyncHTTPClient
from tornado.options import define, options
from tornado.stack_context import StackContext

import frontik.handler
import memcache
import tornado.curl_httpclient

import appstat_config

start_recording = recording.start_recording
end_recording = recording.end_recording

pre_call_hook = recording.pre_call_hook
post_call_hook = recording.post_call_hook

def save():
    '''Returns an object that can be passed to restore() to resume
    a suspended record.
    '''
    return recording.recorder

def restore(recorder):
    '''Reactivates a previously-saved recording context.'''
    recording.recorder = recorder


def patch_handler():
    old_init = frontik.handler.PageHandler.__init__
    def __init__(self, *args, **kwargs):
        old_init(self, *args, **kwargs)
        self.__recorder = None
    frontik.handler.PageHandler.__init__ = __init__

    old_exec = frontik.handler.PageHandler._execute
    def _execute(self, transforms, *args, **kwargs):
        if self.get_argument('stattrace', None) is not None:
            self.require_debug_access()
            self.force_stat = True
        else:
            self.force_stat = False
        start_recording(tornado.wsgi.WSGIContainer.environ(self.request), self.force_stat, self.log)
        recorder = save()
        self.log.__dict__['recorder']=recorder
        @contextlib.contextmanager
        def transfer_recorder():
            restore(recorder)
            yield
        with StackContext(transfer_recorder):
            old_exec(self, transforms, *args, **kwargs)
    frontik.handler.PageHandler._execute = _execute

    old_finish = frontik.handler.PageHandler.finish
    def finish(self, chunk=None):
        key = None
        if self.force_stat:
            key = str(self.request_id)
            link = etree.Element('stattracelink')
            link.text = '/appstats/details?key=%s' % key
            self.log.debug(link.text, extra={'stattracelink': link})
        old_finish(self, chunk)
        end_recording(self._status_code, key = key)
    frontik.handler.PageHandler.finish = finish

    old_posts={}
    old_finish_page_cb = frontik.handler.PageHandler._finish_page_cb
    def _finish_page_cb(self):
        if self.config not in old_posts:
            old_posts[self.config] = self.config.postprocessor.__call__
            @wraps(self.config.postprocessor.__call__) #, assigned=[])
            def post_wrap(handler, chunk, cb):
                recording.pre_call_hook('POST', str(self.config.postprocessor), chunk, None)
                old_posts[self.config](handler, chunk, cb)
            self.config.postprocessor.__call__ = post_wrap
        old_finish_page_cb(self)
    frontik.handler.PageHandler._finish_page_cb = _finish_page_cb

    old_wait_postprocessor = frontik.handler.PageHandler._wait_postprocessor
    def _wait_postprocessor(self, start_time, data):
        recording.post_call_hook('POST', str(self.config.postprocessor), None, data)
        old_wait_postprocessor(self, start_time, data)

    frontik.handler.PageHandler._wait_postprocessor = _wait_postprocessor


def patch_logger():
    old_stage_tag = frontik.handler.PageLogger.stage_tag
    def stage_tag(self, stage):
        if hasattr(self.recorder, 'record_custom_event'):
            self.recorder.record_custom_event(stage)
        old_stage_tag(self, stage)
    frontik.handler.PageLogger.stage_tag = stage_tag

    old_DebugPageHandler_handle = frontik.handler_xml_debug.DebugPageHandler.handle
    def handle(self, record):
        old_DebugPageHandler_handle(self, record)
        if hasattr(record, "stattracelink"):
            self.log_data[-1].append(record.stattracelink)
    frontik.handler_xml_debug.DebugPageHandler.handle = handle


def patch_curl():
    def _request_method_url(request):
        '''Returns a tuple (method, url) for use in recording traces.

        Accepts either a url or HTTPRequest object, like HTTPClient.fetch.
        '''
        if isinstance(request, tornado.httpclient.HTTPRequest):
            return (request.method, request.url.partition('?')[0].rpartition('//')[2])
        else:
            return ('GET', request)

    def _response_info(response):
        if isinstance(response, tornado.httpclient.HTTPResponse):
            return ' '.join(map(str, filter(None, [response.error, response.code, response.body])))
        else:
            return repr(response)

    def _request_info(request):
        if isinstance(request, tornado.httpclient.HTTPRequest):
            return ' '.join(map(str, filter(None, [request.body])))
        else:
            return repr(request)


    old_fetch = CurlAsyncHTTPClient.fetch
    def fetch(self, request, callback, *args, **kwargs):
        method, url = _request_method_url(request)
        recording.pre_call_hook('HTTP.'+method, url, _request_info(request), None)
        def wrapper(request, callback, response, *args):
            recording.post_call_hook('HTTP.'+ method, url, _request_info(request), _response_info(response))
            callback(response)
        old_fetch(self,
          request,
          functools.partial(wrapper, request, callback),
          *args, **kwargs)
    CurlAsyncHTTPClient.fetch = fetch

def patch_handler_xml():
    old_prepare_xsl = frontik.handler_xml.PageHandlerXML._prepare_finish_with_xsl
    def _prepare_finish_with_xsl(self):
        recording.pre_call_hook('XSL.transform', self.transform_filename, self.doc, None)
        result = old_prepare_xsl(self)
        recording.post_call_hook('XSL.transform', self.transform_filename, self.doc, result)
        return result
    frontik.handler_xml.PageHandlerXML._prepare_finish_with_xsl = _prepare_finish_with_xsl

def patch_memclient():

    old_set_multi = memcache.Client.set_multi
    def set_multi(self, mapping, time=0, key_prefix='', min_compress_len=0):
        recording.pre_call_hook('MEMCACHE.set', key_prefix, mapping, None)
        res = old_set_multi(self, mapping, time, key_prefix, min_compress_len)
        recording.post_call_hook('MEMCACHE.set', key_prefix, mapping, res)
        return res
    memcache.Client.set_multi = set_multi

    old_get_multi = memcache.Client.get_multi
    def get_multi(self, keys, key_prefix=''):
        recording.pre_call_hook('MEMCACHE.get', key_prefix, keys, None)
        res = old_get_multi(self, keys, key_prefix)
        recording.post_call_hook('MEMCACHE.get', key_prefix, keys, res)
        return res
    memcache.Client.get_multi = get_multi

def patch_all():
    patch_handler()
    patch_logger()
    patch_curl()
    patch_handler_xml()
    patch_memclient()
