#!/bin/sh

# script por para listar os recursos da AWS

RESULT_ARNS="/tmp/lab/result-arns.log"

ARN_FILE="/tmp/lab/arnslist.log"

mkdir -p /tmp/lab/arns

REGIONS="sa-east-1"

fn_get_arns()
{
  for region in $(echo $REGIONS)
  do
    aws --region $region cloudformation list-types --visibility PUBLIC --max-results 100  | jq -r '. | "\(.NextToken) \(.TypeSummaries[].TypeName)"' > $RESULT_ARNS-$region

    fineshed=false
    while [ "$fineshed" != true ]
    do
      TOKEN_ARN=$(cat $RESULT_ARNS-$region | awk '{ print $1 }' | tail -n1)

      TTLN_LOOP_BEFORE=$(cat $RESULT_ARNS-$region | awk '{ print $2 }' | sort -u | wc -l)

      aws --region $region cloudformation list-types --visibility PUBLIC --max-results 100 --next-token $TOKEN_ARN | jq -r '. | "\(.NextToken) \(.TypeSummaries[].TypeName)"' >> $RESULT_ARNS-$region

      TTLN_LOOP_AFTER=$(cat $RESULT_ARNS-$region | awk '{ print $2 }' | sort -u | wc -l)

      if [ $TTLN_LOOP_BEFORE -eq $TTLN_LOOP_AFTER ]
      then
        fineshed=true
      fi
    done
  done
}

fn_uniq_arns()
{
  for region in $(echo $REGIONS)
  do
    for listArns in $(cat $RESULT_ARNS-$region | awk '{ print $2 }' | sort -u)
    do
      FILE_FINAL_ARN="/tmp/lab/arns/resources-$region-$listArns.json"

      aws --region $region configservice list-discovered-resources --resource-type $listArns > $FILE_FINAL_ARN

    done
  done
}

# main
fn_get_arns
fn_uniq_arns

