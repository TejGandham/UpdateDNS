#!/bin/bash

cd /home/pi/update_dns 
mix run -e "UpdateCloudflareDNS.run()"

