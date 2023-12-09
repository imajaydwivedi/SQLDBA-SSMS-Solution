--	https://helpdeskgeek.com/how-to/how-to-set-up-your-own-email-server/
--	https://www.youtube.com/watch?v=vDQxsiln6pk

Add CNAME record with below names
---------------------------------
contso.com
mail.contso.com
smtp.mail.contso.com
pop3.mail.contso.com

Add firewall Inbuid rules
--------------------------
%ProgramFiles% (x86)\hMailServer\Bin\hMailServer.exe

hMailServer (TCP/ 25,110,143,587)
hMailServer (UDP/ 25,110,143,587)

Configure Mail Client
-----
Incoming - IMAP - mail.contso.com - 143
Outgoing - SMTP - mail.contso.com - 587
