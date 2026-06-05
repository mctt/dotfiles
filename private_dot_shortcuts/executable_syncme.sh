#!/bin/bash
rsync -uva ~/storage/shared/syncme/ 192.168.0.42::syncme
sleep 10
