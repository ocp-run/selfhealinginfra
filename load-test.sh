#!/bin/sh
#test
for i in {1..8}
do
    requests=$((100+50*i));echo "output: iteration $i"; echo "$requests requests for minute $i and running hey tool";
    ./hey -c $requests -q 1 -z 30s -m GET https://beer-native-beer.apps.ocp4rony.dfw.ocp.run/
done
#run at constant high load for 10 minutes
./hey -c 500 -q 1 -z 10m -m GET https://beer-native-beer.apps.ocp4rony.dfw.ocp.run/
