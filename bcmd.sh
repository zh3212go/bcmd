#!/bin/sh
#Edit by zh at 2015.6
#set -x
#version v2.95
export LANG=C

ping_timeout=3
ssh_timeout=20
scp_timeout=3600

#myecho() { for ((i=1;i<$((`echo $1|wc -L`+1));i++));do echo -n `echo $1|cut -c$i`;sleep 0.005;done;echo \n }

if ( ! which expect ) > /dev/null 2>&1
then
    echo -e "\e[31;1mSorry, Please install the \"expect\" package!\e[0m"
    exit 1
fi
current_user=`whoami`
LOCK_NAME="/tmp/bcmd.$current_user.lock"
if ( set -o noclobber; echo "$$" > "$LOCK_NAME" ) 2> /dev/null 
then
    trap 'rm -f "$LOCK_NAME"; exit $?' INT TERM EXIT
else
    echo -e "\e[31;5mSomebody is using this script with $current_user user, You should wait for quit or switch another user!\e[0m"
    exit 1
fi

DIR=$PWD
if [ -r /tmp/bcmd.$current_user.dirinfo ]
then
    DIR=`tail -1 /tmp/bcmd.$current_user.dirinfo`
fi
if [ ! -r $DIR/iplist.txt ]
then
    echo "Hello~~~ I need to access the iplist.txt file, and it format as IP ACCOUNT PASSWD, Are you ready (yes or no)?"
    read -p "---> " Y
    if [ "$Y" != "yes" ]
    then
        echo "Goodbye~ You should edit it at first, I will wait for you ..."
        exit 1
    fi
    echo "So, Can you tell me the location of the iplist.txt? Like this:  iplist.txt=/tmp/iplist.txt"
    read -p "---> " L
    L=`echo "$L" | cut -f2 -d"=" -s | sed 's/ //g' | sed "s#~#$HOME#"`
    if [ -f "$L" ]
    then
        if [ -r "$L" ]
        then
            DIR=`echo "$L" | sed 's/\/iplist.txt//'`
            echo "$DIR" > /tmp/bcmd.$current_user.dirinfo
        else
            echo -e "\e[31;1mSorry, I cann't read the iplist.txt file! Because $L cann't be accessed by the user $current_user!\e[0m"
            exit 1
        fi 
    elif ! ( cd "`echo "$L" | sed 's/\/iplist.txt//'`"; ) 2> /dev/null
    then
        echo -e "\e[31;1mSorry, $current_user cann't enter the `echo "$L" | sed 's/\/iplist.txt//'` directory!\e[0m"
        exit 1
    else
        echo -e "\e[31;1mSorry, Cann't find the iplist.txt in `echo "$L" | sed 's/\/iplist.txt//'` directory! I really need it ...\e[0m"
        exit 1
    fi
else
    echo "$DIR" > /tmp/bcmd.$current_user.dirinfo
fi

if ! ( mkdir -p $DIR/log; ) 2> /dev/null
then    
    echo -e "\e[31;1mWarning!! The $DIR can not be written by the user $current_user !\e[0m"
    exit 1
fi

if ! ( >$DIR/log/pingerr.$current_user.log ) 2> /dev/null
then    
    echo -e "\e[31;1mWarning!! The $DIR/log can not be written by the user $current_user !\e[0m"
    exit 1
fi
>$DIR/log/ssherr.$current_user.log
>$DIR/log/scperr.$current_user.log
>$DIR/log/execute_result.$current_user.log
>$DIR/log/command_history.$current_user.log
rm -f $DIR/log/*.tmp.$current_user.*
rm -f $DIR/iplist.txt.tmp
chmod 600 $DIR/iplist.txt 2> /dev/null
sed -i 's/ \+/ /g;s/^[ \t]*//g;/^$/d' $DIR/iplist.txt
num=`cat $DIR/iplist.txt | wc -l`
x=0
while read IP ACCOUNT PASSWD PORT
do
if [ `echo -e "${IP//./\n}"|wc -l` -ne 4 -o "$ACCOUNT" == "" -o "$PASSWD" == "" ]
then
    echo -e "\e[31;1mWarning!! $DIR/iplist.txt is incorrect! Please check and format as IP ACCOUNT PASSWD\e[0m"
    x=1
fi
echo "$ACCOUNT" | egrep "\W" > /dev/null
if [ $? -eq 0 ]
then
    echo -e "\e[31;1mWarning!! The user $ACCOUNT is not a legal user!\e[0m"
    x=1
fi
ping -c 1 -w $ping_timeout $IP|grep 'min/avg/max/mdev' > /dev/null
if [ $? -ne 0 ]
then
    ssh -o ConnectTimeout=1 $IP -p 32121 > $DIR/log/pingerr_test.$current_user.log 2>&1
    cat $DIR/log/pingerr_test.$current_user.log | grep "Connection refused" > /dev/null
    if [ $? -ne 0 ]
    then
        echo "$IP ping failed!" >> $DIR/log/pingerr.$current_user.log
        echo -e "\e[31;1mWarning!! $IP ping failed! You should check this failed host!\e[0m"
        x=1
    fi
fi
done <$DIR/iplist.txt
if [ `awk '{print $1}' $DIR/iplist.txt | sort -u | wc -l` -ne $num ]
then
    echo -e "\e[31;1mWarning!! $DIR/iplist.txt can't include the duplicate IP address!\e[0m"
    x=1
fi
if [ $x -ne 0 ]
then
    exit 1
fi

i=0
r=0
q=0
e=0
P="~"
sqlplus_flag=0
mysql_flag=0
echo -e "\e[34;42;1mWelcome to bcmd v2.9 (Use q to exit,Use h to help)\e[0m"
while true
do
i=$(($i+1))
if [ $q -ne $i ]
then
    S=`tail -1 $DIR/log/command_history."$current_user".log`
    echo "$S" | cut -f2- -d" " -s | grep -E "ls|ll|cat|grep|top|tail|head|echo|pwd|wc|hostname|uname|uptime|stat|list|ifconfig|route|ping|^df|^id|^env|^ps|^date|^who|^select|^alter|^show|^desc" > /dev/null
    c1=$?
    echo "$S" | cut -f2- -d" " -s | grep ">" > /dev/null
    c2=$?   
    sed -n '/COMMAND'$(($i-1))'\s/,$p' $DIR/log/execute_result.$current_user.log | egrep -iE "command not found|Operation not permitted|Is a directory|not exist|No such file or directory|ORA-|^ERROR| +ERROR|CRS-|^SP2-|Access denied" > /dev/null
    c3=$?
    if [ $c1 -eq 0 -a $c2 -eq 1 -a $r -eq 0 -o $c3 -eq 0 -a $r -eq 0 ]
    then
        sed -n '/COMMAND'$(($i-1))'\s/,$p' $DIR/log/execute_result.$current_user.log | more
        r=1
        i=$(($i-1))
        continue
    fi
    if [ $c3 -eq 0 -a $i -gt 1 ]
    then
        e=-1
    elif [ $c3 -eq 1 -a $i -gt 1 ]
    then
        e=1
    else
        e=0
    fi
    if [ "`tail -1 $DIR/log/command_history.$current_user.log | cut -d" " -f2- -s`" == "mysql" ]
    then
        if [ $c3 -ne 0 ]
        then
            mysql_flag=1
            echo -e "\e[1m--- Open mysql mode successfully , You can execute the SQL statement , and enter \"nomysql\" for quit! ---\e[0m"
        else
            mysql_flag=0
            echo -e "\e[31;1m--- Open mysql mode failed! You should check mysql environment , and mysql user or password! ---\e[0m"
        fi
    fi
    if [ "`tail -1 $DIR/log/command_history.$current_user.log | cut -d" " -f2- -s`" == "sqlplus" ]
    then
        if [ $c3 -ne 0 ]
        then
            sqlplus_flag=1
            echo -e "\e[1m--- Open sqlplus mode successfully , You can execute the SQL statement , and enter \"nosqlplus\" for quit! ---\e[0m"
        else
            sqlplus_flag=0
            echo -e "\e[31;1m--- Open sqlplus mode failed! You should check the remote oracle environment! ---\e[0m"
        fi
    fi
    sed -n '/COMMAND'$(($i-1))'\s/,$p' $DIR/log/execute_result.$current_user.log | grep -iE "No such file or directory|Not a directory|Permission denied" > /dev/null
    c1=$?
    sed -n '/COMMAND'$(($i-1))'\s/,$p' $DIR/log/execute_result.$current_user.log | grep -iE "Permission denied" > /dev/null
    c2=$?
    if [ $c1 -eq 1 -a "`echo "$S" | cut -f2 -d" "`" == "cd" ]
    then
        OP=$P
        TP=`echo "$S" | tr -s [:space:] | cut -f3 -d" " -s`
        if [ "$TP" == "" ]
        then
            P="~"
        elif [ "$TP" == "/" ]
        then
            P="/"
        elif [ "$TP" == ".." -o "$TP" == "../" ]
        then
            if ( ! dirname $P ) > /dev/null 2>&1
            then
                echo -e "\e[31;1mSorry, Please input the full path!\e[0m"
            else 
                P=`dirname $P`
            fi
        elif [ "$TP" == "../.." -o "$TP" == "../../" ]
        then
            if ( ! dirname $P ) > /dev/null 2>&1
            then
                echo -e "\e[31;1mSorry, Please input the full path!\e[0m"
            else 
                P_TMP=`dirname $P`
                P=`dirname $P_TMP`
            fi
        else
            TP=`echo $TP | sed 's/\/$//g'`
            echo $TP| egrep '^/|~|^\$' > /dev/null
            if [ $? -eq 0 ]
            then
                P=$TP
            else
                P=$P/$TP
            fi
        fi
    elif [ $c1 -eq 0 -a "`echo "$S" | cut -f2 -d" "`" == "cd" ]
    then        
        if [ $c2 -eq 1 ]
        then
            echo -e "\e[31;1mWarning!! No such file or directory!\e[0m"
        else
            echo -e "\e[31;1mWarning!! `echo "$S"|cut -f2- -d" "` : Permission denied!\e[0m"
        fi
        P=$P    
    else
        P=$P
    fi
fi
q=$i

if ( ! basename $P ) > /dev/null 2>&1
then
    P=$OP
    echo -e "\e[31;1mSorry, Please input the full path!\e[0m"
fi

n=`cat $DIR/iplist.txt | wc -l`
read -rp "$i#[`basename $P`]--> " COMMAND
#COMMAND=`echo "$COMMAND" |  tr -s [:space:]`
COMMAND_=$COMMAND
echo "$COMMAND" | grep -E "^vi|^passwd|tail +-f|^cd +-|^watch|more|less|^ssh|^telnet|^sqlplus +-|^mysql +-" > /dev/null
if [ $? -eq 0 ]
then
    echo -e "\e[31;1mSorry , This command can not be executed in this script , you should do it with another way!\e[0m"
    i=$(($i-1))  
    continue    
fi

T1=`echo "$COMMAND" | cut -f1 -d" "`
T2=`echo "$COMMAND" | cut -f2 -d" " -s`
T3=`echo "$COMMAND" | cut -f3 -d" " -s`

if [ "$T1" == "" ]
then
    i=$(($i-1))
    continue
fi

if [ "$T1" == "#" ]
then
    echo $T2 | egrep '^[0-9]+$' > /dev/null
    c1=$?
    echo $T2 | egrep '^[0-9]+-[0-9]+$' > /dev/null
    c2=$?
    if [ $c1 -eq 0 -a "$T3" == "" ]
    then
        if [ $T2 -le `cat $DIR/iplist.txt|wc -l` -a $T2 -ne 0 ]
        then
            if [ $num -eq `cat $DIR/iplist.txt|wc -l` ]
            then
                cp -f $DIR/iplist.txt $DIR/iplist.txt.original
            fi
            sed -i ''$T2'd' $DIR/iplist.txt
            if [ `cat $DIR/iplist.txt | wc -l` -gt 0 ]
            then
                echo "The current iplist is as follows :"
                cat -b $DIR/iplist.txt
            fi            
        else
            echo -e "\e[31;1mWarning!! Can't find this NUMBER, enter \"v\" query the NUMBER!\e[0m"
        fi
    elif [ $c2 -eq 0 -a "$T3" == "" ] 
    then
        num1=`echo $T2 | cut -f1 -d"-" -s`
        num2=`echo $T2 | cut -f2 -d"-" -s`
        if [ $num1 -lt $num2 ]
        then
            if [ $num2 -le `cat $DIR/iplist.txt|wc -l` -a $num1 -ne 0 ]
            then
                if [ $num -eq `cat $DIR/iplist.txt|wc -l` ]
                then
                    cp -f $DIR/iplist.txt $DIR/iplist.txt.original
                fi
                sed -i ''$num1','$num2'd' $DIR/iplist.txt
                if [ `cat $DIR/iplist.txt | wc -l` -gt 0 ]
                then
                    echo "The current iplist is as follows :"
                    cat -b $DIR/iplist.txt
                fi
            else
                echo -e "\e[31;1mWarning!! Can't find this NUMBER, enter \"v\" query the NUMBER!\e[0m"
            fi   
        else
            echo -e "\e[31;1mWarning!! The NUMBER1 can't less then the NUMBER2!\e[0m"
        fi
    else
        echo -e "\e[31;1mWarning!! Please ensure your command like \"# NUMBER|NUMBER1-NUMBER2\"\e[0m"
    fi
    i=$(($i-1))
    continue
fi

if [ "$T1" == "##" ]
then
    if [ "$T2" == "" ]
    then
        if [ -f $DIR/iplist.txt.original ]
        then
            mv -f $DIR/iplist.txt.original $DIR/iplist.txt
        fi
        echo "The current iplist is as follows :"
        cat -b $DIR/iplist.txt
    else
        echo -e "\e[31;1mWarning!! Please ensure your command like \"##\"\e[0m"
    fi
    i=$(($i-1))
    continue
fi

if [ $T1 == "/" ]
then
    if [ "$T2" == "" ]
    then
        if [ $e -eq 1 ]
        then
            COMMAND=`tail -1 $DIR/log/command_history.$current_user.log | cut -d" " -f2- -s`
            COMMAND_=$COMMAND
            T1=`echo "$COMMAND" | cut -f1 -d" "`
            T2=`echo "$COMMAND" | cut -f2 -d" " -s`
            T3=`echo "$COMMAND" | cut -f3 -d" " -s`
        elif [ $e -eq 0 ]
        then
            echo -e "\e[31;1mWarning!! You have no command input!\e[0m"
            i=$(($i-1))
            continue
        else
            echo -e "\e[31;1mWarning!! The previous command has failed!\e[0m"
            i=$(($i-1))
            continue
        fi
    else
        echo -e "\e[31;1mWarning!! Please ensure your command like \"/\"\e[0m"
        i=$(($i-1))
        continue
    fi
fi

echo $T1 | cut -c1 | egrep "[a-z]|/|>|\." > /dev/null      
c1=$?
echo $T1 | egrep '^H|^\[\[A|^\[\[B|^\[\[C|^\[\[D' > /dev/null
c2=$?
if [ $c1 -eq 1 -o $c2 -eq 0 ]
then
    echo -e "\e[31;1mWarning!! May be input error , Please check and input again!\e[0m"
    i=$(($i-1))  
    continue
fi

if [ "$T1" == "h" -o "$T1" == "help" -o "$T1" == "?" ]
then
    echo "--- Notes: You can try to copy bcmd to /bin and use rlwrap tool. ---"
    echo "======================================================================================================================="
    echo "h                                                   --help"
    echo "l                                                   --list history commands"
    echo "v                                                   --show the current iplist" 
    echo "p                                                   --print the latest result"
    echo "/                                                   --execute the previous command"
    echo "p all                                               --print all executed results"
    echo "p IP                                                --print all the results of a host"
    echo "p NUMBER                                            --print one of executed results (Enter \"l\" query the NUMBER)"
    echo "p NUMBER IP                                         --print one of hosts in one of executed results"
    echo "s FILES|DIRS[,FILES|DIRS...] REMOTEDIR              --send local files or dirs to all remote hosts , separate by \",\" "
    echo "r FILES|DIRS LOCALDIR                               --receive files or dirs from all remote hosts" 
    echo "# NUMBER|NUMBER1-NUMBER2                            --reverse selection some hosts (Enter \"v\" query the NUMBER)"
    echo "##                                                  --cancel the all reverse selection"
    echo "sqlplus                                             --open sqlplus mode"
    echo "nosqlplus                                           --quit sqlplus mode"
    echo "mysql                                               --open mysql mode"
    echo "nomysql                                             --quit mysql mode"
    echo "m                                                   --query current mode"
    echo "c                                                   --clear the terminal screen"
    echo "q                                                   --exit this script"
    echo "======================================================================================================================="
    echo "--- Any bugs about this script please contact zh3212@126.com , Thank you ! ---"
    i=$(($i-1))
    continue
fi

if [ "$T1" == "q" -o "$T1" == "Q" -o "$T1" == "quit" -o "$T1" == "QUIT" -o "$T1" == "exit" -o "$T1" == "EXIT" ]
then
    if [ -f $DIR/iplist.txt.original ]
    then
        mv -f $DIR/iplist.txt.original $DIR/iplist.txt
    fi
    rm -f $DIR/iplist.txt.tmp
    if [ $n -ne 0 ]
    then
        echo -e "\e[1mFor the security, I will delete the contents of the iplist.txt, ok? (\"ok\" or \"no\")\e[0m"
        read -p "$i#[`basename $P`]--> " CONFIRM
        if [ "$CONFIRM" == "ok" -o "$CONFIRM" == "OK" -o "$CONFIRM" == "yes" -o "$CONFIRM" == "YES" ]
        then
            >$DIR/iplist.txt
            echo -e "\e[1;1mThe contents of the iplist.txt has been deleted! Goodbye~\e[0m"        
        else
            echo -e "\e[1;1mThe contents of the iplist.txt has been reserved! Goodbye~\e[0m"
        fi
    fi
    rm -f $LOCK_NAME
    trap - INT TERM EXIT
    break
fi

if [ "$T1" == "l" ]
then
    if [ `cat $DIR/log/command_history.$current_user.log | wc -l` -gt 0 ]
    then
        echo "------------ History command --------------"
        more $DIR/log/command_history.$current_user.log
        echo "------------------ end --------------------"
    else
        echo -e "\e[31;1mWarning!! You have no command input!\e[0m"
    fi
    i=$(($i-1))
    continue
fi

if [ "$COMMAND" == "p all" ]
then
    more $DIR/log/execute_result.$current_user.log
    i=$(($i-1))
    continue
fi

if [ "$T1" == "p" ]
then
    if [ "$T2" == ""  ]
    then
        sed -n '/COMMAND'$(($i-1))'\s/,$p' $DIR/log/execute_result.$current_user.log | more
    else
        echo $T2 | egrep '^[0-9]+$' > /dev/null
        d1=$?
        if [ $d1 -eq 0 -a "$T3" == "" ]
        then
            if [ $T2 -lt $i ]
            then
                sed -n '/COMMAND'$T2'\s/,/COMMAND'$(($T2+1))'\s/p' $DIR/log/execute_result.$current_user.log | grep -v COMMAND$(($T2+1)) | more
            else
                echo -e "\e[31;1mWarning!! Executed $(($i-1)) commands , Not found the COMMAND$T2 !\e[0m"
            fi
        elif [ $d1 -eq 0 -a `echo -e "${T3//./\n}" | wc -l` -eq 4 ]
        then
            cat $DIR/iplist.txt | grep "^$T3" > /dev/null
            d2=$?
            if [ $d2 -eq 0 -a $T2 -lt $i ]
            then
                sed -n '/COMMAND'$T2'\s/,/COMMAND'$(($T2+1))'\s/p' $DIR/log/execute_result.$current_user.log | grep -v COMMAND$(($T2+1)) | sed -n '/ --> '$T3'$/,/@^_^@/p' | more
            elif [ $d2 -ne 0 ]
            then
                echo -e "\e[31;1mWarning!! This IP is not in the iplist.txt!\e[0m"
            elif [ $T2 -ge $i ]
            then
                echo -e "\e[31;1mWarning!! Executed $(($i-1)) commands , Not found the COMMAND$T2 !\e[0m"
            else
                echo -e "\e[31;1mWarning!! Please ensure your command like \"p [NUMBER] [IP]\"\e[0m"
            fi
        elif [ `echo -e "${T2//./\n}" | wc -l` -eq 4 -a "$T3" == "" ]
        then
            cat $DIR/iplist.txt | grep "^$T2" > /dev/null
            if [ $? -eq 0 ]
            then
                sed -n '/ --> '$T2'$/,/@^_^@/p' $DIR/log/execute_result.$current_user.log | more
            else
                echo -e "\e[31;1mWarning!! This IP is not in the iplist.txt!\e[0m"
            fi
        else
            echo -e "\e[31;1mWarning!! Please ensure your command like \"p [NUMBER] [IP]\"\e[0m"
        fi
    fi
    i=$(($i-1))
    continue
fi

if [ "$T1" == "rm" -o "$T1" == "shutdown" -o "$T1" == "init" ]
then
    echo -e "\e[31;1mPlease confirm , and enter \"yes\" or \"no\" ?\e[0m"
    read -p "$i#[`basename $P`]--> " CONFIRM
    if [ "$CONFIRM" != "yes" ]
    then
        echo -e "\e[31;1mWarning!! This command has been cancelled!\e[0m"  
        i=$(($i-1))  
        continue      
    fi
fi

if [ "$T1" == "ll" ]
then
    COMMAND="ls -l ""`echo "$COMMAND" | cut -f2- -d" " -s`"
fi

if [ "$T1" == "ping" ]
then
    COMMAND="ping -c4 ""`echo "$COMMAND" | cut -f2- -d" " -s`"
fi

if [ "$T1" == "top" ]
then
    COMMAND="top -bcn 1"
fi

echo "$T1" | egrep '^iostat' > /dev/null
if [ $? -eq 0 ]
then
    COMMAND="iostat -d 2 3"
fi

echo "$T1" | egrep '^vmstat' > /dev/null
if [ $? -eq 0 ]
then
    COMMAND="vmstat 1 5"
fi

scp_flag=0
if [ "$T1" == "s" ]
then      
    if [ "$T2" == "" -o "$T3" == "" -o `echo -e "${COMMAND// /\n}" | wc -l` -gt 3 ]
    then
        echo -e "\e[31;1mWarning!! Please ensure your command like \"s FILES|DIRS[,FILES|DIRS...] REMOTEDIR\"\e[0m"
        i=$(($i-1))
        continue
    fi
    scp_flag=-1
fi

if [ "$T1" == "r" ]
then    
    if [ "$T2" == "" -o "$T3" == "" -o `echo -e "${COMMAND// /\n}" | wc -l` -gt 3 ]
    then
        echo -e "\e[31;1mWarning!! Please ensure your command like \"r FILES|DIRS LOCALDIR\"\e[0m"
        i=$(($i-1))
        continue
    fi
    scp_flag=1
fi

if [ "$T1" == "c" ]
then
    clear
    i=$(($i-1))
    continue
fi

if [ "$T1" == "v" ]
then
    if [ `cat $DIR/iplist.txt | wc -l` -gt 0 ]
    then
        echo "The current iplist is as follows :"
        cat -b $DIR/iplist.txt
    else
        echo -e "\e[31;1mWarning!! There is no host in iplist!\e[0m"
    fi
    i=$(($i-1))
    continue
fi

echo $T1 | egrep '/' > /dev/null
if [ $? -eq 0 ]
then
    T1=`basename $T1`
fi

if [ $n -eq 0 ]
then
    echo -e "\e[31;1mWarning!! There is no host in iplist!\e[0m"
    i=$(($i-1))
    continue
fi

if [ "$COMMAND" == "m" ]
then
    if [ $mysql_flag -eq 1 ]
    then
        echo -e "\e[1mMysql Mode\e[0m"
    elif [ $sqlplus_flag -eq 1 ]
    then
        echo -e "\e[1mSqlplus Mode\e[0m"
    else
        echo -e "\e[1mHost Mode\e[0m"
    fi
    i=$(($i-1))
    continue
fi

if [ "$COMMAND" == "mysql" ]
then
    read -p "Mysql User: " MYSQLUSER
    read -sp "Mysql Password: " MYSQLPASS
    echo ""
    if [ "$MYSQLPASS" == "" ]
    then
        mysql_flag=0
        echo -e "\e[31;1mWarning!! The Password can not be empty!\e[0m"        
        i=$(($i-1))  
        continue
    else
        mysql_flag=1
        sqlplus_flag=0
        COMMAND=""
    fi
fi      

if [ "$COMMAND" == "nomysql" ]
then
    if [ $mysql_flag -eq 1 ]
    then
        mysql_flag=0
        echo -e "\e[1m--- Quit mysql mode successfully! ---\e[0m"
    else
        echo -e "\e[1m--- HOST MODE ---\e[0m"
    fi
    i=$(($i-1))
    continue
fi

if [ "$COMMAND" == "sqlplus" ]
then
    sqlplus_flag=1
    mysql_flag=0
    COMMAND=""
fi

if [ "$COMMAND" == "nosqlplus" ]
then
    if [ $sqlplus_flag -eq 1 ]
    then
        sqlplus_flag=0
        echo -e "\e[1m--- Quit sqlplus mode successfully! ---\e[0m"
    else
        echo -e "\e[1m--- HOST MODE ---\e[0m"
    fi 
    i=$(($i-1))
    continue
fi

if [ $mysql_flag -eq 1 -a $sqlplus_flag -eq 0 ]
then
    echo "$COMMAND" | egrep ";$" > /dev/null
    if [ $? -eq 1 ]
    then
        COMMAND=$COMMAND";"
    fi
    echo "$COMMAND" | egrep -i "^use" > /dev/null
    if [ $? -eq 0 ]
    then
        MYSQL_DB=$COMMAND
        i=$(($i-1))
        continue
    fi
    #MYSQL_SQL=`echo $MYSQL_DB$COMMAND | sed s#\'#\"#g`
    MYSQL_SQL=$MYSQL_DB$COMMAND
    if [ "$MYSQLUSER" == "" ]
    then
        COMMAND="mysql -p$MYSQLPASS -e \"$MYSQL_SQL\""
    else
        COMMAND="mysql -u$MYSQLUSER -p$MYSQLPASS -e \"$MYSQL_SQL\""
    fi
fi

if [ $sqlplus_flag -eq 1 -a $mysql_flag -eq 0 ]
then
    if [ "$COMMAND" != "" ]
    then
        echo "$COMMAND" | egrep ";$" > /dev/null
        if [ $? -eq 1 ]
        then
            COMMAND=$COMMAND";"
        fi
        OT_SQL="set linesize 125;\nset pagesize 1000;\n"
        SQL=""
        echo "$COMMAND" | egrep -i "^col|^set" > /dev/null
        c=$?
        if [ $e -ne -1 -a $c -eq 0 ]
        then
            T_SQL=$T_SQL$COMMAND"\n"
        elif [ $e -eq -1 -a $c -eq 0 ]
        then
            T_SQL=$COMMAND"\n"
        elif [ $e -eq -1 -a $c -ne 0 ]
        then
            T_SQL=""
            SQL=$COMMAND
        else
            SQL=$COMMAND
        fi
    else
        OT_SQL="set linesize 125;\nset pagesize 1000;\n"
        T_SQL=""
        SQL=""
    fi
    #SQL="`echo "$SQL" | sed "s/[\']/\\\\\\\\\\\'/g"`"
    if [ `awk '{print $2}' $DIR/iplist.txt | sort -u | wc -l` -eq 1 -a "`awk '{print $2}' $DIR/iplist.txt | sort -u`" == "root" ]
    then           
        COMMAND="echo -e '$OT_SQL$T_SQL$SQL'>/tmp/bcmd_root_tmp.sql;su - oracle -c 'sqlplus -S / as sysdba <<EOF\n@/tmp/bcmd_root_tmp.sql\nEOF'"
    elif [ `awk '{print $2}' $DIR/iplist.txt | sort -u | wc -l` -eq 1 -a "`awk '{print $2}' $DIR/iplist.txt | sort -u`" == "oracle" ]
    then
        COMMAND="echo -e '$OT_SQL$T_SQL$SQL'>/tmp/bcmd_oracle_tmp.sql;sqlplus -S / as sysdba <<EOF\n@/tmp/bcmd_oracle_tmp.sql\nEOF"
    elif [ `awk '{print $2}' $DIR/iplist.txt | sort -u | wc -l` -eq 1 -a "`awk '{print $2}' $DIR/iplist.txt | sort -u`" == "grid" ]
    then
        COMMAND="echo -e '$OT_SQL$T_SQL$SQL'>/tmp/bcmd_grid_tmp.sql;sqlplus -S / as sysdba <<EOF\n@/tmp/bcmd_grid_tmp.sql\nEOF"
    else
        echo -e "\e[31;1mSQL statements are executed only when the user is the same in iplist , and only be root, oracle or grid!\e[0m"
        i=$(($i-1))
        continue
    fi
fi
cp -f $DIR/iplist.txt $DIR/iplist.txt.tmp
sed -i "s/\\$/\\\\\\\\$/g;s/\\!/\\\\\\\!/g;s/\\[/\\\\\\\\[/g;s/\\]/\\\\\\\\]/g" $DIR/iplist.txt.tmp
T_COMMAND=`echo "$COMMAND" | sed 's#"#\\\"#g' | sed 's#\\\$#\\\\$#g'`
T_P=`echo "$P" | sed 's#"#\\\"#g' | sed 's#\\\$#\\\\$#g'`
echo "$i#[$P]--> $COMMAND_" >> $DIR/log/command_history.$current_user.log
echo "=====================================================>> COMMAND$i --> $COMMAND_" >> $DIR/log/execute_result.$current_user.log
echo "---------------------------------------------------------------------------------------------------------@^_^@" >> $DIR/log/execute_result.$current_user.log
r=0

if [ $scp_flag -eq -1 ]
then
    ls -ltrd `echo "$T2" | sed 's/,/ /g'` > $DIR/log/scp_filelist.tmp.$current_user.test 2>&1
    cat $DIR/log/scp_filelist.tmp.$current_user.test | grep -i "No such file or directory" > /dev/null
    if [ $? -eq 0 ]
    then
        cat $DIR/log/scp_filelist.tmp.$current_user.test | grep -i "No such file or directory" >> $DIR/log/execute_result.$current_user.log
        echo "---------------------------------------------------------------------------------------------------------@^_^@" >> $DIR/log/execute_result.$current_user.log
        cat $DIR/log/scp_filelist.tmp.$current_user.test | grep -i "No such file or directory" | more
        continue
    fi 
    echo "---------------------------------------------------------------------------------------------------------@^_^@"  
    ls -ltrd `echo "$T2" | sed 's/,/ /g'` | awk '{print $5,$9}' > $DIR/log/scp_filelist.tmp.$current_user.$i 
    g1=`ls -lR $T2 | grep "^-" | wc -l`
    while read IP ACCOUNT PASSWD PORT
    do
    if [ "$PORT" == "" ]
    then
        PORT=22
    fi
    echo "scp to remote --> $IP" >> $DIR/log/execute_result.$current_user.log
    echo "scp to remote --> $IP"
    f=0
    g2=0
    while read FILESIZE FILENAME
    do
    f=$(($f+1))
    expect -c > $DIR/log/$T1.tmp.$current_user.$IP-$i-$f 2>&1 "
    set timeout $scp_timeout    
    spawn scp -rp -P $PORT $FILENAME $ACCOUNT@$IP:$T3 
    expect {
    \"yes/no\" {send \"yes\n\"; exp_continue;}
    \"*assword\" {set timeout $scp_timeout; send \"$PASSWD\n\";}
    }
    expect eof
    "
    cat $DIR/log/$T1.tmp.$current_user.$IP-$i-$f | grep -i "password:" > /dev/null
    if [ $? -eq 0 ]
    then
        g2=$(($g2+`sed '1,/[Pp]assword:/d' $DIR/log/$T1.tmp.$current_user.$IP-$i-$f|grep 100%|wc -l`))
        sed '1,/[Pp]assword:/d' $DIR/log/$T1.tmp.$current_user.$IP-$i-$f >> $DIR/log/execute_result.$current_user.log
        sed '1,/[Pp]assword:/d' $DIR/log/$T1.tmp.$current_user.$IP-$i-$f | grep -v "^Killed" | more
        sed '1,/[Pp]assword:/d' $DIR/log/$T1.tmp.$current_user.$IP-$i-$f | grep 100% > /dev/null
        c1=$?
    else
        g2=$(($g2+`sed '/spawn id exp4 not open/,$d' $DIR/log/$T1.tmp.$current_user.$IP-$i-$f|grep 100%|wc -l`))
        sed '/spawn id exp4 not open/,$d' $DIR/log/$T1.tmp.$current_user.$IP-$i-$f | egrep -iv "^Killed|spawn" >> $DIR/log/execute_result.$current_user.log
        sed '/spawn id exp4 not open/,$d' $DIR/log/$T1.tmp.$current_user.$IP-$i-$f | egrep -iv "^Killed|spawn" | more
        sed '/spawn id exp4 not open/,$d' $DIR/log/$T1.tmp.$current_user.$IP-$i-$f | grep 100% > /dev/null
        c1=$? 
    fi
    cat $DIR/log/$T1.tmp.$current_user.$IP-$i-$f | grep -i "Permission denied" > /dev/null
    c2=$?
    if [ $c1 -ne 0 -a $c2 -eq 0 ]
    then
        echo "`date +%Y-%m-%d_%H:%M:%S` ---> scp $FILENAME to $ACCOUNT@$IP:$T3 failed, Permission denied!" >> $DIR/log/scperr.$current_user.log
        echo -e "\e[31;1mscp $FILENAME to $ACCOUNT@$IP:$T3 failed, Permission denied! You should check this failed files , detail in $DIR/log/$T1.tmp.$current_user.$IP-$i-$f\e[0m"
    fi
    if [ $c1 -ne 0 -a $c2 -ne 0 ]
    then
        echo "`date +%Y-%m-%d_%H:%M:%S` ---> scp $FILENAME to $ACCOUNT@$IP:$T3 failed!" >> $DIR/log/scperr.$current_user.log
        echo -e "\e[31;1mscp $FILENAME to $ACCOUNT@$IP:$T3 failed! You should check this failed files , detail in $DIR/log/$T1.tmp.$current_user.$IP-$i-$f\e[0m"
    fi    
    done <$DIR/log/scp_filelist.tmp.$current_user.$i
    if [ $g1 -eq $g2 -a $g2 -ne 0 ]
    then
        echo "----------------------------------- Total $g2 files all send successfully! -----------------------------------" >> $DIR/log/execute_result.$current_user.log
        echo -e "\e[32;1m----------------------------------- Total $g2 files all send successfully! -----------------------------------\e[0m"
    fi
    echo "---------------------------------------------------------------------------------------------------------@^_^@" >> $DIR/log/execute_result.$current_user.log
    echo "---------------------------------------------------------------------------------------------------------@^_^@"
    done <$DIR/iplist.txt.tmp
    continue
fi

if [ $scp_flag -eq 1 ]
then
    touch $T3/bcmdtestfile.tmp > $DIR/log/touch.tmp.$current_user.test 2>&1
    cat $DIR/log/touch.tmp.$current_user.test | grep -i "No such file or directory" > /dev/null
    c1=$?
    cat $DIR/log/touch.tmp.$current_user.test | grep -i "Permission denied" > /dev/null
    c2=$?
    if [ $c1 -eq 0 ]
    then
        echo "$T3: No such file or directory!" >> $DIR/log/execute_result.$current_user.log
        echo "---------------------------------------------------------------------------------------------------------@^_^@" >> $DIR/log/execute_result.$current_user.log
        echo -e "\e[31;1m$T3: No such file or directory!\e[0m"
        continue
    fi
    if [ $c2 -eq 0 ]
    then
        echo "$T3: Permission denied!" >> $DIR/log/execute_result.$current_user.log
        echo "---------------------------------------------------------------------------------------------------------@^_^@" >> $DIR/log/execute_result.$current_user.log
        echo -e "\e[31;1m$T3: Permission denied!\e[0m"
        continue
    fi 
    rm -rf $T3/bcmdtestfile.tmp
    echo "---------------------------------------------------------------------------------------------------------@^_^@"       
    while read IP ACCOUNT PASSWD PORT
    do
    if [ "$PORT" == "" ]
    then
        PORT=22
    fi
    mkdir -p $T3/$IP
    echo "scp to local --> $IP" >> $DIR/log/execute_result.$current_user.log
    echo "scp to local --> $IP"
    expect -c > $DIR/log/$T1.tmp.$current_user.$IP-$i 2>&1 "
    set timeout $scp_timeout    
    spawn scp -rp -P $PORT $ACCOUNT@$IP:$T2 $T3/$IP/ 
    expect {
    \"yes/no\" {send \"yes\n\"; exp_continue;}
    \"*assword\" {set timeout $scp_timeout; send \"$PASSWD\n\";}
    }
    expect eof
    "

    cat $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -i "password:" > /dev/null
    if [ $? -eq 0 ]
    then
        sed '1,/[Pp]assword:/d' $DIR/log/$T1.tmp.$current_user.$IP-$i >> $DIR/log/execute_result.$current_user.log
        sed '1,/[Pp]assword:/d' $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -v "^Killed" | more
        g3=`sed '1,/[Pp]assword:/d' $DIR/log/$T1.tmp.$current_user.$IP-$i | grep 100% | wc -l`
        cat $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -i "Permission denied" > /dev/null
        c1=$?
        cat $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -i "No such file or directory" > /dev/null
        c2=$?
        c3=`sed '1,/[Pp]assword:/d' $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -v 100% | wc -l`
        c3=$(($c3+1))
    else
        sed '/spawn id exp4 not open/,$d' $DIR/log/$T1.tmp.$current_user.$IP-$i | egrep -iv "^Killed|spawn" >> $DIR/log/execute_result.$current_user.log
        sed '/spawn id exp4 not open/,$d' $DIR/log/$T1.tmp.$current_user.$IP-$i | egrep -iv "^Killed|spawn" | more
        g3=`sed '/spawn id exp4 not open/,$d' $DIR/log/$T1.tmp.$current_user.$IP-$i | grep 100% | wc -l`
        cat $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -i "Permission denied" > /dev/null
        c1=$?
        cat $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -i "No such file or directory" > /dev/null
        c2=$?
        c3=`sed '/spawn id exp4 not open/,$d' $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -v 100% | wc -l`
    fi
    if [ $c1 -eq 0 ]
    then
        echo "`date +%Y-%m-%d_%H:%M:%S` ---> scp $ACCOUNT@$IP:$T2 to $T3 failed, Permission denied!" >> $DIR/log/scperr.$current_user.log
        echo -e "\e[31;1mscp $ACCOUNT@$IP:$T2 to $T3 failed, Permission denied! You should check this failed files, detail in $DIR/log/$T1.tmp.$current_user.$IP-$i\e[0m"
    elif [ $c2 -eq 0 ]
    then
        echo "`date +%Y-%m-%d_%H:%M:%S` ---> scp $ACCOUNT@$IP:$T2 to $T3 failed, No such file or directory!" >> $DIR/log/scperr.$current_user.log
        echo -e "\e[31;1mscp $ACCOUNT@$IP:$T2 to $T3 failed, No such file or directory! You should check this failed files, detail in $DIR/log/$T1.tmp.$current_user.$IP-$i\e[0m"
    elif [ $c3 -gt 1 ] 
    then
        echo "`date +%Y-%m-%d_%H:%M:%S` ---> scp $ACCOUNT@$IP:$T2 to $T3 failed!" >> $DIR/log/scperr.$current_user.log
        echo -e "\e[31;1mscp $ACCOUNT@$IP:$T2 to $T3 failed! You should check this failed files, detail in $DIR/log/$T1.tmp.$current_user.$IP-$i\e[0m"
    fi
    echo "------------------------------------ Total $g3 files received successfully! -----------------------------------" >> $DIR/log/execute_result.$current_user.log
    echo -e "\e[32;1m------------------------------------ Total $g3 files received successfully! -----------------------------------\e[0m"
    echo "---------------------------------------------------------------------------------------------------------@^_^@" >> $DIR/log/execute_result.$current_user.log
    echo "---------------------------------------------------------------------------------------------------------@^_^@"
    done <$DIR/iplist.txt.tmp
    continue
fi

while read IP ACCOUNT PASSWD PORT
do
{
if [ "$PORT" == "" ]
then
    PORT=22
fi
echo "Send $COMMAND_ to $IP..."
expect -c > $DIR/log/$T1.tmp.$current_user.$IP-$i 2>&1 "
set timeout $ssh_timeout
spawn ssh $ACCOUNT@$IP -p $PORT \"
source ~/.bash_profile > /dev/null 2>&1
LANG=C
cd $T_P
$T_COMMAND
                       \" 
expect {
\"yes/no\" {send \"yes\n\"; exp_continue;}
\"*assword\" {set timeout $ssh_timeout; send \"$PASSWD\n\";}
}
expect eof
"
cat $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -Ei "^Permission denied|ssh.*Connection refused" > /dev/null
c1=$?
cat $DIR/log/$T1.tmp.$current_user.$IP-$i | grep -i "please try again" > /dev/null
c2=$?
cat $DIR/log/$T1.tmp.$current_user.$IP-$i | egrep -i "^password:|'s password:" > /dev/null
c3=$?
c4=`cat $DIR/log/$T1.tmp.$current_user.$IP-$i | egrep "^Password:" | wc -l`
if [ $c1 -eq 0 ]
then 
    if [ $c2 -eq 0 ]
    then
        echo "`date +%Y-%m-%d_%H:%M:%S` --->  $IP ssh failed , password denied!" >> $DIR/log/ssherr.$current_user.log 
        echo -e "\e[31;1m$IP ssh failed , password denied! You should check this failed host , Please enter \"q\" to exit!\e[0m"
        continue
    else
        echo "`date +%Y-%m-%d_%H:%M:%S` --->  $IP ssh failed , connection refused!" >> $DIR/log/ssherr.$current_user.log
        echo -e "\e[31;1m$IP ssh failed , connection refused! You should check this failed host , Please enter \"q\" to exit!\e[0m"
        continue
    fi
elif [ $c4 -eq 2 ]
then
    echo "`date +%Y-%m-%d_%H:%M:%S` --->  $IP ssh failed , password denied!" >> $DIR/log/ssherr.$current_user.log 
    echo -e "\e[31;1m$IP ssh failed , password denied! You should check this failed host , Please enter \"q\" to exit!\e[0m"
    continue
fi
if [ $c3 -eq 1 ]
then
    echo "password:" > $DIR/log/$T1.tmp.$current_user.$IP-$i
    ssh $ACCOUNT@$IP "source ~/.bash_profile>/dev/null 2>&1;LANG=C;cd $P;$COMMAND"  >> $DIR/log/$T1.tmp.$current_user.$IP-$i 2>&1
fi
sed -i '/Warning: Using a password on the command line interface can be insecure/d' $DIR/log/$T1.tmp.$current_user.$IP-$i
sed -i "/'s [Pp]assword:/a\===============> $COMMAND_ --> $IP" $DIR/log/$T1.tmp.$current_user.$IP-$i
sed -i "/^[Pp]assword:/a\===============> $COMMAND_ --> $IP" $DIR/log/$T1.tmp.$current_user.$IP-$i
echo "---------------------------------------------------------------------------------------------------------@^_^@" >> $DIR/log/$T1.tmp.$current_user.$IP-$i
sed -n '/===============> /,$p' $DIR/log/$T1.tmp.$current_user.$IP-$i >> $DIR/log/execute_result.$current_user.log
}
done <$DIR/iplist.txt.tmp
wait
echo -e "\e[1m--- Total $n hosts have been executed! ---\e[0m"
done

cp $DIR/log/execute_result.$current_user.log $DIR/log/execute_result.$current_user.log.`date +%Y-%m-%d"_"%H:%M:%S`.bak
find $DIR/log/execute_result.*.bak -mtime +30 -exec rm {} \;
#end