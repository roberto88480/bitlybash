#!/bin/bash

#################################################################################
#										#
# 	Script for shortening of URLS via bitly (api v4).			#
#										#
#	Usage:		bitly.sh [ -h | --help ] [ -t | --use-token TOKEN]	#
#				[ --store-token TOKEN]				#
# 				[ -s | --shorten LONGURL]			#
#				[ -l | --login ] [ -j | --json ]		#
#										#
#	Parameter:	-h | --help: Show help					#
#										#
#			-t | --use-token TOKEN: Use TOKEN to authenticate	#
#			against bitly's api. Token will not be stored.		#
# 										#
# 			--store-token TOKEN: Stores an api-token		#
#			in ~/.config/bitly_api_token for later use		#
#										#
#			-s | --shorten LONGURL: Shorten a url using bitly	#
#										#
#			-l | --login: Asks you for bitly.com username and	#
#			password to genreate an api-token and saves the token	#
# 										#
# 			-j | --json: Output full JSON-response			#
#										#
#################################################################################

MYPROG=$0
[ ! -x $MYPROG ] && MYPROG=$(which $0 | awk '{ print $3 }')


CURL=$(which curl)
if [ $? -ne 0 ]
then
	>&2 echo "Cannot find curl. Plase make sure it is installed."
	exit 1;
fi

JQ=$(which jq)
if [ $? -ne 0 ]
then
	echo "Cannot find jq. Plase make sure it is installed."
	exit 1;
fi

APIBASEURL="https://api-ssl.bitly.com/"
TOKENFILE=~/.config/bitly_api_token
ACTION=""
APITOKEN=$(head -n 1 ${TOKENFILE})
APIRESPONSE=""
JSONOUTPUT=false

function _usage()
{
	grep "^#.*#$" $MYPROG
	exit $1
}

function _storeToken()
{
	if [[ ${#1} -gt 5 ]]
	then
		echo $1 > $TOKENFILE
	else
		>&2 echo "Invalid Token"
		exit 1
	fi
}

function _checkTokenFile()
{
	if test -f "$TOKENFILE"; then
		echo "File $TOKENFILE already exists."
		read -p "Overwrite it? " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]
		then
			[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
		fi
	fi
}

while [ -n "$1" ]
do
	case "$1" in
		-h|--help)
			_usage 0
		;;
		-t|--use-token)
			shift
			APITOKEN=$1
		;;
		--store-token)
			shift
			_checkTokenFile
			_storeToken $1
		;;
		-s|--shorten)
			shift
			if [[ $1 == http://* ]] || [[ $1 == https://* ]]
			then
				LONGURL=$1
			else
				LONGURL='http://'$1
			fi
		;;
		-l|--login)
			# ask for username and password
			# query api for access token
			# save token to userdata
			_checkTokenFile
			echo "Please enter your Bitly.com Username and Password"
			read -p 'Username: ' username
			read -sp 'Password: ' password
			echo
			if [[ -z "$username" ]] || [[ -z "$password" ]]
			then
				echo "Username/Password can not be empty!"
				exit 1
			else
				APIRESPONSE=$($CURL --silent --user "${username}:${password}" --request POST ${APIBASEURL}oauth/access_token)
				if [[ $? -eq 0 ]]
				then
					_storeToken ${APIRESPONSE} true
				else
					echo "Error"
					echo ${APIRESPONSE}
					exit 1
				fi
			fi
			break
		;;
		-j|--json)
			# Output response as json
			JSONOUTPUT=true
		;;
		*)
			_usage 2
		;;
	esac
	shift
done

if [ -n "$LONGURL" ]
then
	if [ ! -n "$APITOKEN" ]
	then
		echo "no api token"
		exit 1
	fi
	APIRESPONSE=$($CURL --silent --header "Authorization: Bearer ${APITOKEN}" --header "Content-Type: application/json" --data "{\"long_url\": \"${LONGURL}\"}" https://api-ssl.bitly.com/v4/shorten)
	if [ "$?" -ne 0 ]
	then
		echo "Something went wrong"
	fi
	if [ ${JSONOUTPUT} == true ]
	then
		echo $APIRESPONSE
	else
		echo $APIRESPONSE | jq '.link' | sed -e 's/^"//' -e 's/"$//'
	fi
fi
