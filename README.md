# pgexec
This repository provides a script and other resources for obtaining command execution from access to a PostgreSQL service, version 8.2 or later, including the 9.x branch. Given credentials for a PostgreSQL service, the script will use SQL queries to upload a C library which contains a wrapper method around libc's system, and can be called using [PostgreSQL's external function mechanisms](https://www.postgresql.org/docs/current/static/xfunc-c.html). The script will then execute the given command on the system.

The help text for the script is as follows:
```
$ ./pg_exec.sh --help
./pg_exec.sh [options]
 Execute a shell commands on a server using PostgreSQL access
 Options:
        --help                  Show this help text and exit
        -U, --user              The username to authenticate to the PostgreSQL server with
        -P, --password          The password to authenticate to the PostgreSQl server with
        -L, --library           A library to upload to the server instead of the default
        -S, --splitdir          The temporary directory to store the split parts of the library in
        -h, --host              The host running the PostgreSQL service
        -p, --port              The port that the PostgreSQL service is running on
        -c, --command           The command to execute on the server
        -e, --export            The path to save the library to on the server
        -s, --source            The source file to compile the library from
        -f, --function          The name of the function to be called in the library
```
