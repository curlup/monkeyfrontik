import xslt
import appstat
import appstat_config
from functools import wraps

from frontik.server import main as fr_main
from tornado.options import options, define
import frontik.app

def patch_app():
    old_get_app = frontik.app.get_app

    @wraps(old_get_app)
    def get_app(app_urls, app_dict=None):
        app = old_get_app(app_urls, app_dict)
        urlspec = appstat_config.get_urlspec('/appstats/.*')
        app.handlers[0][1].insert(0, urlspec)

        return app

    frontik.app.get_app = get_app

def main(config_file="/etc/frontik/frontik.cfg"):

    xslt.patch_xslt()
    appstat.patch_all()
    options['debug_xsl'].default = '/usr/lib/monkeyfrontik/debug.xsl'
    appstat_config.bootstrap_memcache()
    
    patch_app()

    fr_main(config_file)
