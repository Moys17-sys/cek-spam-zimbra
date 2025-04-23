#!/bin/bash

# ========== SETTINGS ==========
LOG_FILE="/opt/zimbra/log/maillog"
LOG_MAILQUEUE="/var/log/zimbra.log"
QUEUE_CHECK=$(postqueue -p | wc -l)
THRESHOLD_QUEUE=10
SMTP_LOG="/var/log/mail.log"
ALERT_EMAIL="helpdesk@tracon.co.id sysadmin@tracon.co.id"

echo "===== [$(date)] Cek Potensi SPAM di Server Zimbra ====="

# 1. Cek jumlah email di antrian postfix
echo "[+] Mengecek antrian email..."
if [ "$QUEUE_CHECK" -gt "$THRESHOLD_QUEUE" ]; then
    echo " ^z   ^o  Antrian email tinggi: $QUEUE_CHECK entri ditemukan!"
else
    echo " ^|^e  Antrian email normal: $QUEUE_CHECK entri."
fi

# 2. Cek IP pengirim mencurigakan yang sering muncul (brute atau spam relay)
echo -e " \n[+] Mendeteksi IP mencurigakan dari log..."
grep "sasl_method=PLAIN" $LOG_MAILQUEUE | awk '{print $12}' | sort | uniq -c | sort -nr | head -20


# 3. Cek user Zimbra yang paling banyak kirim email
echo -e " \n[+] Top 10 akun yang paling banyak kirim email:"
grep "from=<" $LOG_MAILQUEUE | awk -F"from=<" '{print $2}' | awk -F">" '{print $1}' | sort | uniq -c | sort -nr | head -10

# 4. Cek log error smtp auth (bisa jadi brute force)
echo -e " \n[+] Cek percobaan login gagal:"
grep "authentication failed" $LOG_MAILQUEUE | tail -n 10

# 5. Tampilkan koneksi SMTP aktif (jika ada relay aktif)
echo -e " \n[+] Cek koneksi SMTP aktif:"
netstat -tnp | grep ":25" | grep ESTABLISHED

echo -e "\n ^=^z  Jika banyak pengiriman dari satu akun/IP, cek user tersebut atau ganti password."
# Optional: Kirim alert email (jika ada antrian mencurigakan)
if [ "$QUEUE_CHECK" -gt "$THRESHOLD_QUEUE" ]; then
    REPORT_FILE="/tmp/zimbra_spam_alert.txt"
    {
        echo "Tanggal: $(date)"
        echo "Server: $(hostname)"
        echo ""
        echo "Peringatan! Antrian email terlalu banyak di server Zimbra:"
        echo "Jumlah antrian saat ini: $QUEUE_CHECK"
        echo ""
        echo "Top 10 akun yang banyak kirim email:"
        grep "from=<" $LOG_MAILQUEUE | awk -F"from=<" '{print $2}' | awk -F">" '{print $1}' | sort | uniq -c | sort -nr | head -10
        echo ""
        echo "IP mencurigakan (auth PLAIN):"
        grep "sasl_method=PLAIN" $LOG_MAILQUEUE | awk '{print $12}' | sort | uniq -c | sort -nr | head -10
        echo -e " \n[+] Cek percobaan login gagal:"
        grep "authentication failed" $LOG_MAILQUEUE | tail -n 10
        echo -e " \n[+] Cek koneksi SMTP aktif:"
        netstat -tnp | grep ":25" | grep ESTABLISHED
        echo -e "\n ^=^z  Jika banyak pengiriman dari satu akun/IP, cek user tersebut atau ganti password."

    } > $REPORT_FILE

    mail -s "[ALERT] antrian Email diServer Zimbra Tinggi di $(hostname)" $ALERT_EMAIL < $REPORT_FILE

    rm -f $REPORT_FILE
fi

