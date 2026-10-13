//------------------------------------------------------------------------------
// <copyright file="CSSqlStoredProcedure.cs" company="Microsoft">
//     Copyright (c) Microsoft Corporation.  All rights reserved.
// </copyright>
//------------------------------------------------------------------------------
using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Web;
using System.Net;
using System.Text;
using System.Xml;
using System.IO;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void WebReqMsg(string URL, string Header, SqlString Msg, string ResponseAccept, string MsgType, string MsgMethod, out int StatusCode, out string StatusDesc, out string RetMsg)
    {

        RetMsg = "";
        var request = (HttpWebRequest)WebRequest.Create(URL);
        request.Method = MsgMethod;
        request.Accept = ResponseAccept;
        request.ContentType = MsgType;
        request.Timeout = 30000;
        request.UserAgent = "3P2vegPq5GYSFpNKDzU6QNWREyNEH96XtQa7MeJXkwwu6deX";
        //request.Accept = "application/json"; //"application/xml"
        //request.ContentType = "application/x-www-form-urlencoded"; //"application/json"; //"application/xml";
        //request.Proxy = new WebProxy("http://127.0.0.1:8888");
        request.ProtocolVersion = HttpVersion.Version11;
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
    
        
        //manage header add
        int i = 0;
        string letter;
        string pa = "";
        bool paclosed = false;
        string pav = "";
        while (i < Header.Length)
        {
            letter = Header.Substring(i, 1);

            if (letter == ":")
            {
                paclosed = true;
            }
            if (letter == "&")
            {
                //Console.WriteLine(pa);
                //Console.WriteLine(pav);
                request.Headers.Add(pa, pav);
                paclosed = false;
                pa = "";
                pav = "";
            }
            if (paclosed == false)
            {
                if (letter != "&")
                {
                    pa = pa + letter;
                }
            }
            else
            {
                if (letter != ":")
                {
                    pav = pav + letter;
                }

            }
            i++;
        }
        if (MsgMethod != "GET" && MsgMethod != "DELETE")
        {

            byte[] postBytes = Encoding.UTF8.GetBytes(Msg.Value);
           // byte[] postBytes = Encoding.Convert(Encoding.Unicode, Encoding.UTF8, getBytes);
            request.ContentLength = postBytes.Length;
            var responsestream = request.GetRequestStream();
            responsestream.Write(postBytes, 0, postBytes.Length);
        }
        HttpWebResponse response;
        HttpWebResponse responseERR;

        try
        {
            response = (HttpWebResponse)request.GetResponse();
            long length = response.ContentLength;
            Stream stream = response.GetResponseStream();
            using (var reader = new StreamReader(stream, Encoding.UTF8))
            {
                string responseString = reader.ReadToEnd();
                int responseStatus = (int)response.StatusCode;

                //Add out values
                StatusCode = responseStatus;
                StatusDesc = response.StatusDescription;
                RetMsg = responseString;
            }
        }
        catch (WebException ex)
        {
            if (ex.Response != null)
            {
                using (var responseReader = new StreamReader(ex.Response.GetResponseStream()))
                {
                    var exMessage = responseReader.ReadToEnd();
                    responseERR = (HttpWebResponse)ex.Response;
                    RetMsg = exMessage;
                    var retstatuscode = responseERR.StatusCode;
                    StatusCode = (int)retstatuscode;
                    StatusDesc = responseERR.StatusDescription.ToString();
                }
            }
            else
            {
                StatusCode = 0;
                StatusDesc = ex.Message;
                RetMsg = ex.StackTrace;
            }
            //RetMsg = "";
        }
        catch (Exception ex)
        {
            StatusCode = 0;
            StatusDesc = ex.Message;
            RetMsg = ex.StackTrace;
        }
    }

    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void BinaryWebReqMsg(string URL, string Header, string Msg, string ResponseAccept, string MsgType, string MsgMethod, out int StatusCode, out string StatusDesc, out string RetMsg)
    {

        RetMsg = "";
        var request = (HttpWebRequest)WebRequest.Create(URL);
        request.Method = MsgMethod;
        request.Accept = ResponseAccept;
        request.ContentType = MsgType;
        request.Timeout = 30000;
        request.UserAgent = "3P2vegPq5GYSFpNKDzU6QNWREyNEH96XtQa7MeJXkwwu6deX";
        //request.ServicePoint.ConnectionLeaseTimeout = 30000;
        //request.ServicePoint.MaxIdleTime = 30000;
        //request.Accept = "application/json"; //"application/xml"
        //request.ContentType = "application/x-www-form-urlencoded"; //"application/json"; //"application/xml";
        //request.Proxy = new WebProxy("http://127.0.0.1:8888");
        request.ProtocolVersion = HttpVersion.Version11;
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

        //manage header add
        int i = 0;
        string letter;
        string pa = "";
        bool paclosed = false;
        string pav = "";
        while (i < Header.Length)
        {
            letter = Header.Substring(i, 1);

            if (letter == ":")
            {
                paclosed = true;
            }
            if (letter == "&")
            {
                //Console.WriteLine(pa);
                //Console.WriteLine(pav);
                request.Headers.Add(pa, pav);
                paclosed = false;
                pa = "";
                pav = "";
            }
            if (paclosed == false)
            {
                if (letter != "&")
                {
                    pa = pa + letter;
                }
            }
            else
            {
                if (letter != ":")
                {
                    pav = pav + letter;
                }

            }
            i++;
        }
        if (MsgMethod != "GET" && MsgMethod != "DELETE")
        {
            var messageParts = Msg.Split(';');
            var id = messageParts[0];
            var msg = messageParts[1];
            var bodyStart = $"--{id}" +
                $"\nContent-Disposition: form-data; name=\"file\"; filename=\"{id}.pdf\"" +
                $"\nContent-Type: application/pdf" +
                $"\n\n";

            var pdf = Convert.FromBase64String(msg);
            var bodyStartBytes = Encoding.UTF8.GetBytes(bodyStart);
            var bodyEndBytes = Encoding.UTF8.GetBytes($"\n--{id}");

            var postBytes = new byte[bodyStartBytes.Length + pdf.Length + bodyEndBytes.Length];
            Array.Copy(bodyStartBytes, 0, postBytes, 0, bodyStartBytes.Length);
            Array.Copy(pdf, 0, postBytes, bodyStartBytes.Length, pdf.Length);
            Array.Copy(bodyEndBytes, 0, postBytes, bodyStartBytes.Length + pdf.Length, bodyEndBytes.Length);

            // byte[] postBytes = 
            request.ContentLength = postBytes.Length;
            var responsestream = request.GetRequestStream();
            responsestream.Write(postBytes, 0, postBytes.Length);
        }
        HttpWebResponse response;
        HttpWebResponse responseERR;

        try
        {
            response = (HttpWebResponse)request.GetResponse();
            long length = response.ContentLength;
            Stream stream = response.GetResponseStream();
            using (var reader = new StreamReader(stream, Encoding.UTF8))
            {
                string responseString = reader.ReadToEnd();
                int responseStatus = (int)response.StatusCode;

                //Add out values
                StatusCode = responseStatus;
                StatusDesc = response.StatusDescription;
                RetMsg = responseString;
            }
        }
        catch (WebException ex)
        {
            if (ex.Response != null)
            {
                using (var responseReader = new StreamReader(ex.Response.GetResponseStream()))
                {
                    var exMessage = responseReader.ReadToEnd();
                    responseERR = (HttpWebResponse)ex.Response;
                    RetMsg = exMessage;
                    var retstatuscode = responseERR.StatusCode;
                    StatusCode = (int)retstatuscode;
                    StatusDesc = responseERR.StatusDescription.ToString();
                }
            }
            else
            {
                StatusCode = 0;
                StatusDesc = ex.Message;
                RetMsg = ex.StackTrace;
            }
            //RetMsg = "";
        }
        catch (Exception ex)
        {
            StatusCode = 0;
            StatusDesc = ex.Message;
            RetMsg = ex.StackTrace;
        }
    }
}
