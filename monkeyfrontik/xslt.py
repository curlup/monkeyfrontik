from tornado.options import options

def patch_xslt():
    import frontik.handler_xml_debug
    import frontik.handler_xml
    import time
    import copy

    old_DebugPageHandler = frontik.handler_xml_debug.DebugPageHandler
    class DebugPageHandler(old_DebugPageHandler):
        def handle(self, record):
            old_DebugPageHandler.handle(self, record)
            if getattr(record, "xsltprofile", None):
                self.log_data[-1].append(record.xsltprofile)

    class PageHandlerDebug(frontik.handler_xml_debug.PageHandlerDebug):
        def get_debug_page(self, status_code, **kwargs):
            self.debug_log_handler.log_data.set("xsltprofile", self.handler.get_argument('xsltprofile',''))
            return super(PageHandlerDebug, self).get_debug_page(status_code, **kwargs)

    class PageHandlerXML(frontik.handler_xml.PageHandlerXML):
        def __init__(self, handler):
            if handler.get_argument('xsltprofile', None) is not None:
                handler.require_debug_access()
                self.xslt_profile = True
            else:
                self.xslt_profile = False
            super(PageHandlerXML, self).__init__(handler)

        def set_xsl(self, filename):
            super(PageHandlerXML, self).set_xsl(filename)
            if self.xslt_profile:
                # transform (XSLT object) changes state in case of profiling
                self.transform = copy.deepcopy(self.transform)

        def _prepare_finish_with_xsl(self):
            self.log.debug('finishing with xsl')
            if not self.handler._headers.get("Content-Type", None):
                self.handler.set_header('Content-Type', 'text/html')
            try:
                t = time.time()
                result = self.transform(self.doc.to_etree_element(),profile_run=self.xslt_profile)
                self.log.stage_tag("xsl")
                self.log.debug('applied XSL %s in %.2fms', self.transform_filename, (time.time() - t)*1000)
                self.log.debug('xsl messages: %s' % " ".join(map("message: {0.message}".format, self.transform.error_log)))
                if self.xslt_profile:
                    self.log.debug('xslt profiling affected timings.',extra={'xsltprofile':result.xslt_profile.getroot()})
                    del self.transform
                return str(result)
            except:
                self.log.exception('failed transformation with XSL %s' % self.transform_filename)
                self.log.exception('error_log entries: %s' % "\n".join(map("message from line: {0.line}, column: {0.column}, \
                domain: {0.domain_name}, type: {0.type_name}\
                level: {0.level_name}, file : {0.filename}, message: {0.message}".format, self.transform.error_log)))
                raise

    frontik.handler_xml.PageHandlerXML = PageHandlerXML
    frontik.handler_xml_debug.PageHandlerDebug = PageHandlerDebug
    frontik.handler_xml_debug.DebugPageHandler = DebugPageHandler