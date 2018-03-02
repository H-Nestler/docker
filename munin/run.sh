#!/bin/bash

# timezone settings
TZ=${TZ:="Europe/Paris"}
echo $TZ > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# change cron setting for updates
CRONDELAY=${CRONDELAY:=5}
sed -i "s/\*\/5/\*\/$CRONDELAY/g" /etc/cron.d/munin

# configure default node name
THISNODENAME=${THISNODENAME:="munin"}
sed -i "s/^\[localhost\.localdomain\]/\[$THISNODENAME\]/g" /etc/munin/munin.conf

# configure default servername
THISSERVERNAME=${SERVERNAME:="munin"}
sed -i "s/^\[localhost\.localdomain\]/\[$SERVERNAME\]/g" /etc/apache2/sites-available/000-default.conf

# configure mail notification

if [[ -n "$MAILCONTACT" && -n "$MAILSERVER" && -n "$MAILPORT" && -n "$MAILUSER" && -n "$MAILPASSWORD" && -n "$MAILDOMAIN" ]] ; then
  MAILCONTACT=${MAILCONTACT:="contact@domain.test"}
  sed -i "s/^\[mailcontact]/\[$MAILCONTACT\]/g" /etc/ssmtp/ssmtp.conf
  sed -i "s/^\[mailcontact]/\[$MAILCONTACT\]/g" /etc/munin/munin-conf.d/munin_mail.conf
  MAILSERVER=${MAILSERVER:="mail.domain.test"}
  sed -i "s/^\[mailserver]/\[$MAILSERVER\]/g" /etc/ssmtp/ssmtp.conf
  MAILPORT=${MAILPORT:="25"}
  sed -i "s/^\[mailport]/\[$MAILPORT\]/g" /etc/ssmtp/ssmtp.conf
  MAILSERVER=${MAILUSER:="alert@domain.test"}
  sed -i "s/^\[mailuser]/\[$MAILUSER\]/g" /etc/ssmtp/ssmtp.conf
  MAILPASSWORD=${MAILPASSWORD:="alert@domain.test"}
  sed -i "s/^\[mailpassword]/\[$MAILPASSWORD\]/g" /etc/ssmtp/ssmtp.conf
  MAILSERVER=${MAILDOMAIN:="domain.test"}
  sed -i "s/^\[maildomain]/\[$MAILDOMAIN\]/g" /etc/ssmtp/ssmtp.conf
else
  rm /etc/munin/munin-conf.d/munin_mail.conf /etc/ssmtp/ssmtp.conf
fi

# configure Slack notification

if [[ -n "$SLACKCHANNEL" && -n "$SLACKWEBHOOKURL" ]] ; then
  SLACKCHANNEL=${SLACKCHANNEL:="hosting"}
  sed -i "s/^\[slackchannel]/\[$SLACKCHANNEL\]/g" /usr/local/bin/notify_slack_munin
  SLACKWEBHOOKURL=${SLACKWEBHOOKURL:="https://hooks.slack.com/services/XXXXX/YYYYYYY/ZZZZZZZ"}
  sed -i "s/^\[slackwebhookurl]/\[$SLACKWEBHOOKURL\]/g" /usr/local/bin/notify_slack_munin
  SLACKUSER=${SLACKUSER:="munin"}
  sed -i "s/^\[slackuser]/\[$SLACKUSER\]/g" /usr/local/bin/notify_slack_munin
  SLACKICON=${SLACKICON:="hosting"}
  sed -i "s/^\[slackicon]/\[$SLACKICON\]/g" /usr/local/bin/notify_slack_munin
  sed -i "s/^\[muninurl]/\[$SERVERNAME\]/g" /usr/local/bin/notify_slack_munin
  sed -i "s/^\[muninurl]/\[$SERVERNAME\]/g" /etc/munin/munin-conf.d/munin_slack.conf
else
  rm /etc/munin/munin-conf.d/munin_slack.conf
fi

# generate node list
NODES=${NODES:-}
for NODE in $NODES
do
    NAME=`echo $NODE | cut -d ':' -f1`
    HOST=`echo $NODE | cut -d ':' -f2`
    grep -q $HOST /etc/munin/munin.conf || cat << EOF >> /etc/munin/munin.conf
[$NAME]
    address $HOST
    use_node_name yes

EOF
done

# placeholder html to prevent permission error
if [ ! -f /var/cache/munin/www/index.html ]; then
    cat << EOF > /var/cache/munin/www/index.html
<html>
  <head>
    <title>Munin</title>
  </head>
  <body>
    Munin has not run yet.  Please try again in a few moments.
  </body>
</html>
EOF
    chown -R munin: /var/cache/munin/www/index.html
fi

# start cron
/usr/sbin/cron &

# start local munin-node
/usr/sbin/munin-node > /dev/null 2>&1 &

# confirm nodes
echo "Using the following munin nodes:"
echo " $THISNODENAME"
echo " $NODES"

# start apache
/usr/sbin/apache2ctl start

# display logs
touch /var/log/munin/munin-update.log
chown munin:munin /var/log/munin/munin-update.log
tail -f /var/log/munin/munin-*.log
