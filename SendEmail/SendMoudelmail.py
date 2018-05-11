#!/usr/bin/python
import smtplib
import email
import sys,os,re



def sendconfig(SMTPname='',SMTPuser='',SMTPpass=''):
    ''' configration send mail sever'''
    if not SMTPname : SMTPname=raw_input('SMTPserverName?')
    if not SMTPuser : SMTPuser=raw_input('SMTPusername?')
    if not SMTPpass : SMTPpass=raw_input('SMTPServerPassword?')
    return SMTPname,SMTPuser,SMTPpass

def SMTPconnect(server,user,passwd):
    '''login SMTP server'''
    if not (server and user and passwd):
        print 'incomplete login info, exit now'
        return
    try:
        smtp = smtplib.SMTP()        
        smtp.set_debuglevel(1) # display debug infomation
        smtp.connect(server)
        smtp.login(user, passwd)
        print "****** Login Success!"
        return smtp
    except smtplib.SMTPAuthenticationError:
        print 'The username and/or password you entered was incorrect.'
    except :
        print "Error: smtp login exception! exit now."
        return  

class MailCreator: 
    '''Create a object of message'''
    def __init__ (self):
        self.msg = email.Message.Message()
        self.mail = ""  
    
    def ChooseContentType(self,FileName,isFast=1):
        '''choose a Content-type for inline file or attachment file'''
        
        p=re.compile('\.(?P<suffix>\w+)$', re.IGNORECASE)
        suffix=p.search(FileName).group('suffix')    # get suffix 
        
        ContentType='application/octet- stream'     #default content type
        
        if isFast:
            MIMETypeDic={'xls':'application/vnd.ms-excel',
                         'jpg':'image/jpeg',
                         'gif':'image/gif',
                         'txt':'text/plain',
                         'htm':'text/html',
                         'html':'text/html',
                         'zip':'application/zip',
                         'rar':'application/x-rar-compressed'}            
        else:
            f = open( "MIMEType.txt" , "r" )
            typeList=f.readlines()
            f.close()
            MIMETypeDic=dict( [ tuple(x.rstrip().split(':'))  for x in typeList ])  
        if MIMETypeDic.has_key(suffix):
                ContentType=MIMETypeDic[suffix]
                
        return ContentType       
            
    
    def create(self, mailheader, maildata=[], mailattachlist = []):
        ''' mailheader is dict type, 
            maildata is list consisting of tuples; In a tuple,first option is type,second is the real data. 
            mailattachlist is list with attachments' name in it'''
        if not mailheader:
            return
        
        # add header and if subject is Chinese ,use decode 'gb2312
        for k in mailheader.keys():
             # deal with subject by a special methods ,Chinese font need to translate
             if k == 'subject' :
                 self.msg[k] = email.Header.Header(mailheader[k], 'utf-8' )     
             else :
                 self.msg[k] = mailheader[k]
             
       
        # add content body
        attach = email.MIMEMultipart.MIMEMultipart()
        for data in maildata:
            if data[0]=='plain':          # create plain text
                body = email.MIMEText.MIMEText(data[1], _subtype = 'plain' , _charset = 'utf-8' )
            elif data[0]=='html':
                body = email.MIMEText.MIMEText(data[1], _subtype = 'html' , _charset = 'utf-8' )
            #add deal method for other data type #
            #elif data[0]=''                     #
            else:
                # check the file 
                if os.path.isfile(data[1]):
                    FileName=os.path.basename(data[1])                    
                else:
                    print data[1]+' : no such file or it is not a file!'
                    continue   
                
                Content_Type=self.ChooseContentType(FileName,1)
                body = email.MIMEText.MIMEText(open(data[1], 'rb').read(), 'base64', 'utf-8')
                body["Content-Type"] = Content_Type      #'application/vnd.ms-excel'
                body.add_header('Content-Disposition','inline',filename=FileName)                
            attach.attach(body)       
        

        # deal with attachments
        for fname in mailattachlist:
            # check the file 
            if os.path.isfile(fname):
                FileName=os.path.basename(fname)
            elif os.path.isfile(fname.decode('utf8').encode('gb2312')):  #deal with chinese file             
                FileName=os.path.basename(fname)
                fname=fname.decode('utf8').encode('gb2312')
            else:
                print fname+' : no such file or it is not a file!'
                continue   
                
            Content_Type=self.ChooseContentType(FileName,1)
            attachment = email.MIMEText.MIMEText(email.Encoders._bencode(open(fname, 'rb' ).read()))
            #
            attachment.replace_header( 'Content-type' ,Content_Type)
            #
            attachment.replace_header( 'Content-Transfer-Encoding','base64')
            attachment.add_header( 'Content-Disposition' ,'attachment',filename=FileName)
            
            
            attach.attach(attachment)
        #
                  
        self.mail = self.msg.as_string()[:-1] + attach.as_string()
        
        return self.mail
def createMail(header,data='',attachments=''):
    messageCreater = MailCreator()
    mail = messageCreater.create(header, data, attachments)
    return mail
def sendMail(toWho,fromWho='',mailBody='',serv='smtp.ym.163.com',usr='integration@acuteangle.cn',passwd='sjx1234'):
    server=SMTPconnect(serv,usr,passwd) 
    server.sendmail(fromWho, toWho, mailBody)
    server.quit() 

if __name__=='__main__':
     
     header = { 'from' : 'integration@acuteangle.cn' , 'to' : 'test@acuteangle.cn' ,'cc' : 'cc@acuteangle.cn','subject' : 'email test' }
     piece1='''<p><font size="3">Dear all,<br></br>     <br> Today's DailySoftware located in Path: tmppath       </br><br></br>  <br>  Please download the sw, and check your bugs resolved or not</br> </font></p><br></br>'''
     piece2='''<p><br><font size="2">Thanks!</font></br></p>'''
     data =[('html',piece1),('img',r'/home/likewise-open/SAGEMWIRELESS/92940/sw_download/buglist_resolved.txt'),('html',piece2)]
     if sys.platform == 'win32' :
        attach = [  ]
     else :
	attach = ['/home/likewise-open/SAGEMWIRELESS/92940/sw_download/buglist_resolved.txt']
    
     mail = createMail(header, data, attach)
 
     server=SMTPconnect('smtp.ym.163.com','integration@acuteangle.cn','sjx1234') 
     receivers=[] # receive mail persons
     receivers=['hujianwei@acuteangle.cn.g', 'yiweicheng@acuteangle.cn','luolaigang@acuteangle.cn']
     server.sendmail(['integration@acuteangle.cn'],receivers,mail)
     server.quit() 

