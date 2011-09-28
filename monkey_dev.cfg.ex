host = "0.0.0.0"
port = 9300
workers_count = 1

#daemonize = True
daemonize = False
debug = True

handlers_count = 50
suppressed_loggers = ['tornado.httpclient', 'tornado.curl_httpclient', 'tornado.ioloop']

loglevel = "debug"

from frontik.app import App
urls = [
    ("/tru", App("tru", "/path/to/xhh/frontik_www")),
]

