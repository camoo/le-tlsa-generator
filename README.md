# GENERATE DANE FOR TLSA RECORD WHEN using LET'S ENCRYPT Certificate

## Installation:
- clone the repo

`sudo cp -p le-tlsa /usr/local/bin/le-tlsa`

## SYNOPSIS
    tlsa [--help| -h] [--type| -t <311|211>] [--domain| -d <domain.tld>] [--port| -p <25>]

## DESCRIPTION
    le-tlsa gerenates the needed DANE FOR TLSA DNS RECORD
    Use this script only if you are using Let's Encrypt Certificate

## OPTIONS
--help | -h
    Prints the synopsis and a list of the most commonly used commands.
-t | --type <311|211>
    Sets the TLSA Certificate Usages, TLSA-Selectors and TLSA Matching Types for DANE TLSA DNS-Record. This script only support 3 1 1 and 2 1 1
-d | --domain <domain.tld>
    Sets domain name for which DANE record should be generated. Default domain if not specified is the defined server hostname. Relevant only for type 311
-p | --port <port-number>
    Sets port number for which DANE record should be generated. Default port if not specified is 25
