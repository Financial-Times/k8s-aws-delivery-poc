#!/usr/bin/env bash

TEMPLATE_FILE=cluster-template.yaml
RESULTING_FILE=cluster.yaml
CONFIGS_FOLDER=cluster-configs


function printUsage() {
  me=`basename "$0"`
  echo "Usage: ${me} cluster-config-props"
  valid_cluster_configs=$(find ${CONFIGS_FOLDER} -name "*.properties" | sed "s/.*\/\(.*\)\.properties/\1/g")
  echo "The cluster-config-props are located in the folder '${CONFIGS_FOLDER}', so it may have one of the values:"
  echo "${valid_cluster_configs}"
  exit 1
}

if [ $# -eq 0 ]; then
    printUsage
fi

echo "Generating ${RESULTING_FILE} from template ${TEMPLATE_FILE} from input $1"
cp -f ${TEMPLATE_FILE} ${RESULTING_FILE}

while read line; do
  if [ $(echo -n "${line}" | grep -c "=" ) -eq 1 ]; then
    KEY=$(echo -n "${line}" | awk -F "=" '{print $1}')
    VALUE="$(echo -n "${line}" | awk -F "=" '{print $2}')"

    echo "Replacing key ${KEY} with value ${VALUE} .... "

    # escape the value, as it will be used as sed replacement
    VALUE=$(echo -n "${VALUE}" | sed -e 's/[\ /&$]/\\&/g')
    sed -i.bak "s/\$${KEY}/${VALUE}/g" ${RESULTING_FILE}
  fi
done <${CONFIGS_FOLDER}/$1.properties
