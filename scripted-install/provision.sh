#!/bin/sh
echo
echo "############# Provisioning Started #############"
echo 

ANSIBLE_API_URL="<<ANSIBLE API URL>>"
ANSIBLE_API_TOKEN="<<ANSIBLE API Token"

DYNA_API_URL="<<DYNATRACE API URL>>"     # Sample - "https://mlb*****.live.dynatrace.com/api/v2/problems/{problemId}/comments"
DYNA_API_TOKEN="<<DYNATRACE API TOKEN>>" # Sample - "Api-Token <<Long Token>>"

SNOW_URL="<<Service Now URL>>"  # Sample "servicenow://dev*****?userName=<<User Name>>&password=<<Password>>"

# Replace the below openshift project names as appropriate 
AMQSTREAMS_PROJECT_NAME="amq-cluster"
AMQSTREAMS_PROJECT_DISPLAY_NAME="AMQStreams"

MIDDLEWARE_PROJECT_NAME="middleware"
MIDDLEWARE_PROJECT_DISPLAY_NAME="Middleware"

APP_PROJECT_NAME="beer"
APP_PROJECT_DISPLAY_NAME="BeerApps"

echo "Provisioning Kafka Cluster"
oc new-project $AMQSTREAMS_PROJECT_NAME --display-name=$AMQSTREAMS_PROJECT_DISPLAY_NAME --description=$AMQSTREAMS_PROJECT_DISPLAY_NAME
cat ./amq/operator-group.yml | sed -e "s,namespace-placeholder,$AMQSTREAMS_PROJECT_NAME,g" | oc apply -f -
cat ./amq/amq-subscription.yml | sed -e "s,namespace-placeholder,$AMQSTREAMS_PROJECT_NAME,g" | oc apply -f -
#oc describe sub amq-streams -n amq-cluster1 | grep -A 5 Conditions: | grep -B 1 CatalogSourcesUnhealthy | grep Status: | cut -d\: -f2 | sed 's/^ *//g'
cat ./amq/kafka-setup1.yml | sed -e "s,namespace-placeholder,$AMQSTREAMS_PROJECT_NAME,g" | oc apply -f -
oc wait --for=condition=Ready --timeout=3000s `oc get kafka -o name`
cat ./amq/kafka-setup2.yml | sed -e "s,namespace-placeholder,$AMQSTREAMS_PROJECT_NAME,g" | oc apply -f -

#Generate secret for kafka TLS certficate
echo
echo "Creating Secret"

#if cannot find keytool install java jdk
if ! command -v keytool &> /dev/null
then
    sudo yum install -y java-1.8.0-openjdk
    exit
fi

oc get kafka my-cluster -o=jsonpath='{.status.listeners[1].certificates[0]}' > ./server.crt
keytool -importcert -keystore ./server.jks -storepass password -alias "kafka" -file ./server.crt -trustcacerts -noprompt
keytool -importcert -keystore ./server.jks -storepass password -alias "ansible" -file ./ansible.crt -trustcacerts -noprompt

echo
echo "Creating Applications"
oc new-project $MIDDLEWARE_PROJECT_NAME --display-name=$MIDDLEWARE_PROJECT_DISPLAY_NAME --description=$MIDDLEWARE_PROJECT_DISPLAY_NAME
oc create secret generic att-dyna-integ -n $MIDDLEWARE_PROJECT_NAME --from-file=att-dyna-integ=./server.jks
rm -rf server.jks server.crt

cat ./integ-apps/att-rules.yml | sed -e "s,namespace-placeholder,$MIDDLEWARE_PROJECT_NAME,g" | oc apply -f -
cat ./integ-apps/ansible-pod.yml | sed -e "s,namespace-placeholder,$MIDDLEWARE_PROJECT_NAME,g" | sed -e "s,AAPI_URL,$ANSIBLE_API_URL,g" | sed -e "s,AAPI_TOKEN,$ANSIBLE_API_TOKEN,g" | oc apply -f -
cat ./integ-apps/fuse-pod.yml | sed -e "s,namespace-placeholder,$MIDDLEWARE_PROJECT_NAME,g" | sed -e "s,DAPI_TOKEN,$DYNA_API_TOKEN,g" | sed "s,DAPI_URL,$DYNA_API_URL,g" | sed "s,SAPI_URL,$SNOW_URL,g" | sed -e "s,amq-namespace,$AMQSTREAMS_PROJECT_NAME,g" | oc apply -f -

oc new-project $APP_PROJECT_NAME --display-name=$APP_PROJECT_DISPLAY_NAME --description=$APP_PROJECT_DISPLAY_NAME
cat ./beer-app/beer-app.yml | sed -e "s,namespace-placeholder,$APP_PROJECT_NAME,g" | oc apply -f -
cat ./beer-app/beer-serverless.yml | sed -e "s,namespace-placeholder,$APP_PROJECT_NAME,g" | oc apply -f -

echo
echo "############# Provisioning Completed #############"
echo
