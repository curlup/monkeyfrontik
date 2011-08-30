#!/usr/bin/python
# -*- coding: utf-8 -*-

### BEGIN INIT INFO
# Provides:          frontik
# Required-Start:    $network $remote_fs
# Required-Stop:     $network $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

from tornado_util.supervisor import supervisor

supervisor(
    script='/usr/bin/monkeyfrontik',
    config='/etc/frontik/frontik.cfg'
)
