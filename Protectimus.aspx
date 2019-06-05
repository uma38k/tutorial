<%@ Page language="c#" %>
<%@ Assembly Name="ProtectimusHttpMod, Version=1.0.0.0, Culture=neutral, PublicKeyToken=4f91dfa80e202442" %>
<%

    Protectimus.LogHelper.ErrorRoutine("Inside aspx page");
    bool pageRedirected = false;
    string errorMsg = "";
    string otptext = "";
    Protectimus.ProtectimusOwaMod productModule = new Protectimus.ProtectimusOwaMod();
    Protectimus.MachineConfiguration config = productModule.config;
    Protectimus.CookieEncoder cookieEncoder = new Protectimus.CookieEncoder(config.AKeyBytes);
    Protectimus.CustomCookies custCookies = new Protectimus.CustomCookies(cookieEncoder);
    custCookies.permitInsecureConnectionFromTrustedHost = config.enableInsecureRequests;
    custCookies.insecureConnectionTrustedHosts = config.insecureConnectionTrustedHosts;

    Protectimus.LogHelper.ErrorRoutine("Inside aspx page after initilization");

    // query params - all packed into one signed blob
    string signedParams = Request.QueryString["params"];
    if (String.IsNullOrEmpty(signedParams))
    {
        pageRedirected = true;
        Protectimus.LogHelper.ErrorRoutine("Required parameters not found");
        Response.Redirect(@"/owa", false);
        // throw new Exception("Required parameters not found");
    }
    else
        Protectimus.LogHelper.ErrorRoutine("Required parameters found.");

    if (pageRedirected == false)
    {
        Protectimus.LogBuilder log = new Protectimus.LogBuilder();
        Protectimus.LogHelper.ErrorRoutine("Calling cookieEncoder.TryVerifyCookie");
        string encodedParams = null;
        try
        {
            encodedParams = cookieEncoder.TryVerifyCookie("params", signedParams, log);
        }
        catch(Exception ex)
        {
            //suppress exception while reading invalid cookie
        }
        if (encodedParams == null)
        {
            pageRedirected = true;
            Protectimus.LogHelper.ErrorRoutine(String.Format("Invalid dest parameter: {0}", log.ToString()));
            Response.Redirect(@"/owa", false);
        }

        if (pageRedirected == false)
        {
            System.Collections.Specialized.NameValueCollection paramsDict = System.Web.HttpUtility.ParseQueryString(encodedParams);
            DateTime currentTime = DateTime.UtcNow.AddSeconds(Convert.ToInt64(paramsDict["timeOffset"]));
            string username = paramsDict["username"];
            Protectimus.LogHelper.ErrorRoutine("from aspx page, paramsDict[username] : " + username);
            string dest = paramsDict["dest"];
            Protectimus.LogHelper.ErrorRoutine("from aspx page, paramsDict[dest] : " + dest);



            if (!HttpContext.Current.Request.Cookies.AllKeys.Contains("cadata"))
            {
                pageRedirected = true;
                Response.Redirect(dest, false);
            }

            if (pageRedirected == false)
            {
                Protectimus.LogHelper.ErrorRoutine("pageRedirected == false from aspx page");
                // form values
                string sig_request = "";
                string sig_response = Request.Form["sig_response"];
                string cookieCheckUser = Request.Form["cookie_check_user"];
                otptext = Request.Form["otptext"];

                if (otptext != "" && otptext != null)
                {
                    string errorMsg1 = string.Empty;
                    errorMsg = string.Empty;
                    bool isAuthDone = false;

                    if (Request.Cookies["OTPBtnClicked"] == null || Request.Cookies["OTPBtnClicked"].Value == "No")
                    {
                        isAuthDone = true;
                    }

                    Protectimus.LogHelper.ErrorRoutine("Invalid OTP, msg1 from server : " + errorMsg);
                    if (isAuthDone == false)
                    {
                        Response.Cookies["OTPBtnClicked"].Expires = DateTime.Now.AddMinutes(-20);
                        Response.Cookies["OTPBtnClicked"].Value = "No";
                        Protectimus.LogHelper.ErrorRoutine("Calling productModule.ProtectimusAuthUserToken");
                        if (productModule.ProtectimusAuthUserToken(username, otptext, out errorMsg1))
                        {
                            Protectimus.LogHelper.ErrorRoutine("OTP Login Success, redirecting to inbox page");
                            custCookies.SetCookie(HttpContext.Current, username);
                            Response.Redirect(dest, false);
                        }
                        else
                        {
                            Protectimus.LogHelper.ErrorRoutine("Invalid OTP, OTP Login Failed");
                            if (errorMsg1 == "")
                            {
                                errorMsg = "Invalid OTP";
                                Protectimus.LogHelper.ErrorRoutine("Invalid OTP, msg1 from server : " + errorMsg);
                                otptext = "";
                            }
                            else
                            {
                                errorMsg = errorMsg1;
                                Protectimus.LogHelper.ErrorRoutine("Invalid OTP, msg2 from server : " + errorMsg);
                                otptext = "";
                            }
                        }
                    }
                    else
                    {
                        otptext = "";
                    }
                }
                else
                {
                    try
                    {
                        Protectimus.LogHelper.ErrorRoutine("Calling ProtectimusAuthPrepare from aspx page");
                        string errorMsg1 = string.Empty;
                        bool isOTPSent = true;

                        if (HttpContext.Current != null && HttpContext.Current.Response != null)
                        {
                            Protectimus.LogHelper.ErrorRoutine("Cookie Value = " + Request.Cookies[username + "_OTPSent"].Value);
                            if (Request.Cookies[username + "_OTPSent"] != null && Request.Cookies[username + "_OTPSent"].Value == "UseOnce")
                            {
                                isOTPSent = false;
                            }
                        }

                        if (!isOTPSent)
                        {
                            Protectimus.LogHelper.ErrorRoutine("from aspx page Avoid multi, paramsDict[dest] 0 : " + dest);
                            if (dest == @"/owa/" || dest == @"/owa" || dest.Contains(@"/owa/sessiondata"))
                            {
                                Protectimus.LogHelper.ErrorRoutine("from aspx page Avoid multi, paramsDict[dest] 1 : " + dest);
                                if (!productModule.ProtectimusAuthPrepare(username, out errorMsg1))
                                {
                                    errorMsg = errorMsg1;
                                    Protectimus.LogHelper.ErrorRoutine("ProtectimusAuthPrepare from aspx page, errorMsg" + errorMsg);
                                    Protectimus.LogHelper.ErrorRoutine("ProtectimusAuthPrepare from aspx page, errorMsg1 : " + errorMsg1);
                                }
                                else
                                {
                                    Response.Cookies[username + "_OTPSent"].Expires = DateTime.Now.AddMinutes(-20);
                                    Response.Cookies[username + "_OTPSent"].Value = "UsedTwice";
                                    Protectimus.LogHelper.ErrorRoutine("OTP Sent Block - Cookies cleared");
                                }
                            }
                            else
                            {
                                Protectimus.LogHelper.ErrorRoutine("from aspx page Avoid multi, paramsDict[dest] 2 : " + dest);
                            }

                            Protectimus.LogHelper.ErrorRoutine("OTP Sent Block");
                        }
                        else
                        {
                            Protectimus.LogHelper.ErrorRoutine("OTP Not Sent Block");
                        }
                    }
                    catch (Exception ex)
                    {
                        Protectimus.LogHelper.ErrorRoutine("from aspx page, Calling ProtectimusAuthPrepare, error : " + ex.Message.ToString());
                    }
                }

                string verifiedUser = null;
                if (!String.IsNullOrEmpty(sig_response))
                {
                    Protectimus.LogHelper.ErrorRoutine("if (!String.IsNullOrEmpty(sig_response))-- Calling  Protectimus.Web.VerifyResponse()");
                    verifiedUser = Protectimus.Web.VerifyResponse(config.apiKey, sig_response, currentTime);
                    if (string.IsNullOrEmpty(verifiedUser))
                    {
                        Protectimus.LogHelper.ErrorRoutine("Protectimus.Web.VerifyResponse failed");
                        throw new Exception("Protectimus.Web.VerifyResponse failed");
                    }

                    custCookies.SetCookie(HttpContext.Current, verifiedUser);
                    Protectimus.LogHelper.ErrorRoutine("custCookies.SetCookie verifiedUser" + verifiedUser);
                }
                else if (!String.IsNullOrEmpty(cookieCheckUser))
                {
                    Protectimus.LogHelper.ErrorRoutine("Inside else if (!String.IsNullOrEmpty(cookieCheckUser))");
                    log = new Protectimus.LogBuilder();
                    if (!custCookies.VerifyRequest(Context, cookieCheckUser, log))
                    {
                        Protectimus.LogHelper.ErrorRoutine("Please ensure that you have cookies enabled in your browser.");
                        errorMsg = "Please ensure that you have cookies enabled in your browser.";
                    }
                    else
                    {
                        Protectimus.LogHelper.ErrorRoutine("Response.Redirect to dest : " + dest);
                        Response.Redirect(dest, false);
                        HttpContext.Current.ApplicationInstance.CompleteRequest();
                    }
                }
                else
                {
                    Protectimus.LogHelper.ErrorRoutine("Protectimus.Web.SignRequest()" + sig_request);
                    sig_request = Protectimus.Web.SignRequest(config.apiKey, username, currentTime);
                }
            }
        }
       
    }   
     
%>

<html>
    <body>
        <head>
            <meta http-equiv="X-UA-Compatible" content="IE=10" />
            <meta http-equiv="Content-Type" content="text/html; CHARSET=utf-8">
            <meta name="Robots" content="NOINDEX, NOFOLLOW">
            <style>
                /*Copyright (c) 2003-2006 Microsoft Corporation.  All rights reserved.*/

                body.rtl {
                    text-align: right;
                    direction: rtl;
                }

                body, .mouse, .twide, .tnarrow, form {
                    height: 100%;
                    width: 100%;
                    margin: 0px;
                }

                .mouse, .twide {
                    min-width: 650px; /* min iPad1 dimension */
                    min-height: 650px;
                    position: absolute;
                    top: 0px;
                    bottom: 0px;
                    left: 0px;
                    right: 0px;
                }

                .sidebar {
                    background-color: #0072C6;
                }

                .mouse .sidebar, .twide .sidebar {
                    position: absolute;
                    top: 0px;
                    bottom: 0px;
                    left: 0px;
                    display: inline-block;
                    width: 332px;
                }

                .tnarrow .sidebar {
                    display: none;
                }

                .mouse .owaLogoContainer, .twide .owaLogoContainer {
                    margin: 213px auto auto 109px;
                    text-align: left /* Logo aligns left for both ltr & rtl */
                }

                .tnarrow .owaLogo {
                    display: none;
                }

                .mouse .owaLogoSmall, .twide .owaLogoSmall {
                    display: none;
                }

                .logonDiv {
                    text-align: left;
                }

                .rtl .logonDiv {
                    text-align: right;
                }

                .mouse .logonContainer, .twide .logonContainer {
                    padding-top: 174px;
                    padding-left: 464px;
                    padding-right: 142px;
                    position: absolute;
                    top: 0px;
                    bottom: 0px;
                    left: 0px;
                    right: 0px;
                    text-align: center;
                }

                .mouse .logonDiv, .twide .logonDiv {
                    position: relative;
                    vertical-align: top;
                    display: inline-block;
                    width: 423px;
                }

                .tnarrow .logonDiv {
                    margin: 25px auto auto -130px;
                    position: absolute;
                    left: 50%;
                    width: 260px;
                    padding-bottom: 20px;
                }

                .twide .signInImageHeader, .tnarrow .signInImageHeader {
                    display: none;
                }

                .mouse .signInImageHeader {
                    margin-bottom: 22px;
                }

                .twide .mouseHeader {
                    display: none;
                }

                .mouse .twideHeader {
                    display: none;
                }

                input::-webkit-input-placeholder {
                    font-size: 16px;
                    color: #98A3A6;
                }

                input:-moz-placeholder {
                    font-size: 16px;
                    color: #98A3A6;
                }

                .tnarrow .signInInputLabel, .twide .signInInputLabel {
                    display: none;
                }

                .mouse .signInInputLabel {
                    margin-bottom: 2px;
                }

                .mouse .showPasswordCheck {
                    display: none;
                }

                .signInInputText {
                    border: 1px solid #98A3A6;
                    color: #333333;
                    border-radius: 0;
                    -moz-border-radius: 0;
                    -webkit-border-radius: 0;
                    box-shadow: none;
                    -moz-box-shadow: none;
                    -webkit-box-shadow: none;
                    -webkit-appearance: none;
                    background-color: #FDFDFD;
                    width: 250px;
                    margin-bottom: 10px;
                    box-sizing: content-box;
                    -moz-box-sizing: content-box;
                    -webkit-box-sizing: content-box;
                }

                .mouse .signInInputText {
                    height: 22px;
                    font-size: 12px;
                    padding: 3px 5px;
                    color: #333333;
                    font-family: 'wf_segoe-ui_normal', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    margin-bottom: 20px;
                }

                .twide .signInInputText, .tnarrow .signInInputText {
                    border-color: #666666;
                    height: 22px;
                    font-size: 16px;
                    color: #000000;
                    padding: 7px 7px;
                    font-family: 'wf_segoe-ui_semibold', 'Segoe UI Semibold', 'Segoe WP Semibold', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    margin-bottom: 20px;
                    width: 264px;
                }

                .divMain {
                    width: 444px;
                }

                .l {
                    text-align: left;
                }

                .rtl .l {
                    text-align: right;
                }

                .r {
                    text-align: right;
                }

                .rtl .r {
                    text-align: left;
                }

                table#tblMain {
                    margin-top: 48px;
                    padding: 0px;
                }

                table.mid {
                    width: 385px;
                    border-collapse: collapse;
                    padding: 0px;
                    color: #444444;
                }

                table.tblConn {
                    direction: ltr;
                }

                td.tdConnImg {
                    width: 22px;
                }

                td.tdConn {
                    padding-top: 15px;
                }

                td#mdLft {
                    background: url("lgnleft.gif") repeat-y;
                    width: 15px;
                }

                td#mdRt {
                    background: url("lgnright.gif") repeat-y;
                    width: 15px;
                }

                td#mdMid {
                    padding: 0px 45px;
                    background: #ffffff;
                    vertical-align: top;
                }

                td .txtpad {
                    padding: 3px 6px 3px 0px;
                }

                .txt {
                    padding: 3px;
                    height: 2.2em;
                }

                input.btn {
                    color: #ffffff;
                    background-color: #eb9c12;
                    border: 0px;
                    padding: 2px 6px;
                    margin: 0px 6px;
                    text-align: center;
                }

                .btnOnFcs {
                    color: #ffffff;
                    background-color: #eb9c12;
                    border: 0px;
                    padding: 2px 6px;
                    margin: 0px 6px;
                    text-align: center;
                }

                .btnOnMseOvr {
                    color: #ffffff;
                    background-color: #f9b133;
                    border: 0px;
                    padding: 2px 6px;
                    margin: 0px 6px;
                    text-align: center;
                }

                .btnOnMseDwn {
                    color: #000000;
                    background-color: #f9b133;
                    border: 0px solid #f9b133;
                    padding: 2px 6px;
                    margin: 0px 6px;
                    text-align: center;
                }

                .nowrap {
                    white-space: nowrap;
                }

                hr {
                    height: 0px;
                    visibility: hidden;
                }

                .wrng {
                    color: #ff6c00;
                }

                .disBsc {
                    color: #999999;
                }

                .expl {
                    color: #999999;
                }

                .w100, .txt {
                    width: 100%;
                }

                .txt {
                    margin: 0px 6px;
                }

                .rdo {
                    margin: 0px 12px 0px 32px;
                }

                body.rtl .rdo {
                    margin: 0px 32px 0px 12px;
                }

                tr.expl td, tr.wrng td {
                    padding: 2px 0px 4px;
                }

                tr#trSec td {
                    padding: 3px 0px 8px;
                }
                /* language page specific styles */
                td#tdLng {
                    padding: 12px 0px;
                }

                td#tdTz {
                    padding: 8px 0px;
                }

                select#selTz {
                    padding: 0px;
                    margin: 0px;
                }

                td#tdOptMsg {
                    padding: 10px 0px;
                }

                td#tdOptChk {
                    padding: 0px 0px 15px 65px;
                }

                td#tdOptAcc {
                    vertical-align: middle;
                    padding: 0px 0px 0px 3px;
                }

                select#selLng {
                    margin: 0px 16px;
                }
                /* logoff page specific styles */
                td#tdMsg {
                    margin: 9px 0px 64px;
                }

                input#btnCls {
                    margin: 3px 6px;
                }

                td.lgnTL, td.lgnBL {
                    width: 456px;
                }

                td.lgnTM {
                    background: url("lgntopm.gif") repeat-x;
                    width: 100%;
                }

                td.lgnBM {
                    background: url("lgnbotm.gif") repeat-x;
                    width: 100%;
                }

                td.lgnTR, td.lgnBR {
                    width: 45px;
                }

                table.tblLgn {
                    padding: 0px;
                    margin: 0px;
                    border-collapse: collapse;
                    width: 100%;
                }

                .signInBg {
                    margin: 0px;
                }

                .signInTextHeader {
                    font-size: 60px;
                    color: #404344;
                    font-family: 'wf_segoe-ui_normal', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    margin-bottom: 18px;
                    white-space: nowrap;
                }

                .signInInputLabel {
                    font-size: 12px;
                    color: #666666;
                    font-family: 'wf_segoe-ui_normal', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                }

                .signInCheckBoxText {
                    font-size: 12px;
                    color: #6A7479;
                    font-family: 'wf_segoe-ui_semilight', 'Segoe UI Semilight', 'Segoe WP Semilight', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    margin-top: 16px;
                }

                .twide .signInCheckBoxText, .tnarrow .signInCheckBoxText {
                    font-size: 15px;
                }

                .signInCheckBoxLink {
                    font-size: 12px;
                    color: #0072C6;
                    font-family: 'wf_segoe-ui_semilight', 'Segoe UI Semilight', 'Segoe WP Semilight', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                }

                .signInEnter {
                    font-size: 22px;
                    color: #0072C6;
                    font-family: 'wf_segoe-ui_normal', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    margin-top: 20px;
                }

                .twide .signInEnter {
                    margin-top: 17px;
                    font-size: 29px;
                }

                .tnarrow .signInEnter {
                    margin-top: 2px;
                    font-size: 29px;
                    position: relative;
                    float: left;
                    left: 50%;
                }

                .signinbutton {
                    cursor: pointer;
                    display: inline
                }

                .mouse .signinbutton {
                    padding: 0px 8px 5px 8px;
                    margin-left: -8px;
                }

                .rtl .mouse .signinbutton {
                    margin-right: -8px;
                }

                .tnarrow .signinbutton {
                    position: relative;
                    float: left;
                    left: -50%;
                }

                .shellDialogueHead {
                    font-size: 29px;
                    color: #0072C6;
                    font-family: 'wf_segoe-ui_semilight', 'Segoe UI Semilight', 'Segoe WP Semilight', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                }

                .mouse .shellDialogueHead {
                    line-height: 35px;
                    margin-bottom: 10px;
                }

                .twide .shellDialogueHead, .tnarrow .shellDialogueHead {
                    line-height: 34px;
                    margin-bottom: 12px;
                }

                .shellDialogueMsg {
                    font-size: 13px;
                    color: #333333;
                    font-family: 'wf_segoe-ui_normal', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    line-height: 18px;
                }

                .twide .shellDialogueMsg, .tnarrow .shellDialogueMsg {
                    font-size: 15px;
                }

                .headerMsgDiv {
                    width: 350px;
                    margin-bottom: 22px;
                }

                .twide .headermsgdiv {
                    margin-bottom: 30px;
                }

                .tnarrow .headermsgdiv {
                    width: 260px;
                    margin-bottom: 30px;
                }

                .signInError {
                    font-size: 12px;
                    color: #C1272D;
                    font-family: 'wf_segoe-ui_semilight', 'Segoe UI Semilight', 'Segoe WP Semilight', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    margin-top: 12px;
                }

                .passwordError {
                    color: #A80F22;
                    font-family: 'wf_segoe-ui_normal', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    line-height: 18px;
                }

                .mouse .passwordError {
                    margin-top: 10px;
                    font-size: 13px;
                }

                .twide .passwordError, .tnarrow .passwordError {
                    margin-top: 12px;
                    font-size: 15px;
                }

                .signInExpl {
                    font-size: 12px;
                    color: #999999;
                    font-family: 'wf_segoe-ui_semilight', 'Segoe UI Semilight', 'Segoe WP Semilight', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    margin-top: 5px;
                }

                .signInWarning {
                    font-size: 12px;
                    color: #C1272D;
                    font-family: 'wf_segoe-ui_semilight', 'Segoe UI Semilight', 'Segoe WP Semilight', 'Segoe UI', 'Segoe WP', Tahoma, Arial, sans-serif;
                    margin-top: 5px;
                }

                input.chk {
                    margin-right: 9px;
                    margin-left: 0px;
                }

                .imgLnk {
                    vertical-align: middle;
                    line-height: 2;
                    margin-top: -2px;
                }

                .signinTxt {
                    padding-left: 11px;
                    padding-right: 11px; /* Needed for RTL, doesnt hurt to add this for LTR as well */
                }

                .hidden-submit {
                    border: 0 none;
                    height: 0;
                    width: 0;
                    padding: 0;
                    margin: 0;
                    overflow: hidden;
                }

                .officeFooter {
                    position: absolute;
                    bottom: 33px;
                    right: 45px;
                }

                .tnarrow .officeFooter {
                    display: none;
                }

                #alert-msg {
                    display: none;
                }
            </style>
            <script>
                document.addEventListener("keypress", function (event) {

                    if (event.keyCode === 13) {
                        event.preventDefault();
                        verifyOTP();
                    }
                });
                function setCookie(name, value, days) {
                    var expires = "";
                    if (days) {
                        var date = new Date();
                        date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
                        expires = "; expires=" + date.toUTCString();
                    }
                    document.cookie = name + "=" + (value || "") + expires + "; path=/";
                }
                function verifyOTP() {
                    var otp = document.getElementById('otptext').value;
                    //alert(otp);
                    if (otp == null || otp == '')
                        //alert('Please enter OTP');
                        //errorMsg = "Empty Invalid OTP";
                        document.getElementById('alert-msg').style.display = 'block';
                    else {
                        setCookie('OTPBtnClicked', 'Yes', 2);
                        document.forms[0].submit();
                    }
                }
                function signOut() {
                    delete_cookie('cadata');
                    setCookie('cadata', '', '');
                    location.href = "/owa";
                }
                var delete_cookie = function (name) {
                    document.cookie = name + '=;expires=Thu, 01 Jan 1970 00:00:01 GMT;';
                };
            </script>
        </head>
        <body class="signInBg" style="background: #f2f2f2 url

('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAANvCAYAAADk40vJAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAA

+VpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9

IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXg

tbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iIHhtbG

5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNlUmVmIyIgeG1wOkNyZWF0b3JUb29sPSJBZG9iZ

SBQaG90b3Nob3AgQ1M1IFdpbmRvd3MiIHhtcDpDcmVhdGVEYXRlPSIyMDEyLTA1LTE1VDEzOjEwOjU5LTA3OjAwIiB4bXA6TW9kaWZ5RGF0ZT0iMjAxMi0wNS0xNVQxMzoxMTo0Ni0wNzowMCIgeG1wOk1ldGFkYXRhRGF0

ZT0iMjAxMi0wNS0xNVQxMzoxMTo0Ni0wNzowMCIgZGM6Zm9ybWF0PSJpbWFnZS9wbmciIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6MzI2NTAzNjQ5RUNBMTFFMUFBNkRCNDc2QzU0RjhERUYiIHhtcE1NOkRvY3VtZW5

0SUQ9InhtcC5kaWQ6MzI2NTAzNjU5RUNBMTFFMUFBNkRCNDc2QzU0RjhERUYiPiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDozMjY1MDM2MjlFQ0ExMUUxQUE2REI0NzZDNTRGOERFRi

Igc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDozMjY1MDM2MzlFQ0ExMUUxQUE2REI0NzZDNTRGOERFRiIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/P

nYK5fsAAAFLSURBVHja7NthDoIwDAZQNN7/vCTKKifQgZh12yPx30uG/bqyGLyt6xpLxXVfKi8QBEEQBEEQBEEQBEEQBEEQBEEQBEEQBEEQBEEQBMFh4WP/ePUSBEEQBEHQIQ4EQRA0cUHQdgVBe0Z5QN0Dalx1lAwoGcmA

klEeyShP2/I8QlNoCuWRzJXlCeXRuGfvMSSjcX1rjat7NK6llUcyyqM8kvlh6X3dIhmNe2pp5ZGMpQ8nE8qT9R6LZFLeY0xYHnvm69G1h/NjmXJpjWukSGa4ZGIzUpI+C3vYMzM

+C6Nu6XmH/XwjpZc9I5mkwz6K8iRtXMlI5mwy0TKZV/Zhf/kZd6g903akxJyN28Ow3ySTdKQ0SyZajpRyKfzPr1wNG3czUj5t1x6G/TbhSKlMZqiRcuhk365xI/2wj6aN+0y

+Z25R98LQWH8QeQswAHk7x/k/TxxLAAAAAElFTkSuQmCC') repeat-x" />
        <noscript>
            <div id="dvErr">
                <table cellpadding="0" cellspacing="0">
                    <tr>
                        <td>
                            <img
                                src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAptJREFUeNqkU01LVFEYfu7XzJ17nZmyJBW0sgRDRAgL

oi8tghZG9QNaR7tg2vQjbCu2a9Eq2qRGUYFBZAtLURzSUUcJG8d0ZnTu99fpPdIMSktfOOfcezjP8z7vc94jMMZwmJD5JAhCfWPm0e2+MGKDYRQNBCHrpTWi/1kaExFjY7defp6qneXJhb3pHwGBH4qy8uSIrp9NqjJ0TXs

XuvZ0KfvjacEVsIlEzhXkofuvJ0f+I

+BgVdOftfZe0OIsQBBTFxLX7raxCIH75vn3xOjwQDbQsSgfNw0pkXkwPjXCsWJNNjFlmttPaWrqKBBTEb9yr0No7tCEptaU3H3xMgQJp90imo2C7plGZvhmbx/H7hHwmnUJnWpjI8L1ZSg7fyBoSQWUHo4FIabFwEJE5HeL

X4JmVzqrtjdYN5GM6k95FlhpE4q5A8GzEWzkITYkKYWEqLgG+C58IgiIMx1WkfX0/joBud2Tsrco+wokZ5dAIsL5Scgnu8ACH/7qTyL14RDYo/NJZqPq+D37FYDtlqHlp6n

+xF7WYHkO8ZBkE6G9tgQ3BCwabsTdBwzbw34P5oohfZaKwHYB2CrA+bWCyKwgyC/AIU

+qnIDAAYE3PAmG48/tU8Am1uXU9XR1A4rrQ6S2iHwP9pe3dIc2/OouTCLgJfBYNCVYrj9RV8A7rCIncwvSMWz5JIDUyW2dkXr1DmKnzxFBuVwDZw0JMxXkLC8YqxPw9vSk2NC62mQui2mUA9rsvpSX0o1+vL2r7InxFzXwp

03R/G1GQx9Na6pOwIO3p6U0ZFbjLbl56QRY9tsZbyU7W/jwalyKq4/fb6sYLSq5JUPIfA28kRruwFvgwTuMNwmNG3RV58ntkAyb5jVz2bXMB97CYeKvAAMACjWGjcO+NcIAAAAASUVORK5CYII="
                                alt=""></td>
                        <td style="width: 100%">To use Outlook, browser settings must allow scripts to run. For information about how to allow scripts, consult the Help 

for your browser. If your browser doesn&#39;t support scripts, you can download <a href="http://www.microsoft.com/windows/ie/downloads/default.mspx">Windows Internet 

Explorer</a> for access to Outlook.</td>
                    </tr>
                </table>
            </div>
        </noscript>
        <form method="POST" autocomplete="off">
            <div id="mainLogonDiv" class="mouse">

                <div class="sidebar">
                    <div class="owaLogoContainer">
                        <img
                            src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAABsCAYAAACiuLoyAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyBpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBh

Y2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc

3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdX

Q9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20ve

GFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNSBXaW5kb3dzIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOkMwQzQ2MDA4RjEzRTExRTFCMzNFQTMwMzE5

REU3RjExIiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOkMwQzQ2MDA5RjEzRTExRTFCMzNFQTMwMzE5REU3RjExIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6QzBDNDYwMDZGMTN

FMTFFMUIzM0VBMzAzMTlERTdGMTEiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6QzBDNDYwMDdGMTNFMTFFMUIzM0VBMzAzMTlERTdGMTEiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldG

E

+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"
                            class="owaLogo" aria-hidden="true" />
                        <img
                            src="data:image/png;base64,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

auT6WchoY1bznEeZYo

+L9CogdJAaaCUKHnL0BHmFfY3IrKrZPQBsNTEMGvtAHQBbJrLZy8HwH3jUw61AjBooOz1ICJdW59SVyg7AAMRGZHskJxdO5QAQFdEpiSH6sCdvKEEeo22RQXgpX62uzCQOYAbAAFJH8DkufmBjXySTsK

+HJJr2gskl0yncZjvHJnDUo9htNhAmRlCfg6YNFC22v4AyZ5uswgo26iF6IkPSc5ITrQrd9CkKgjKOjw2yXHCuFygjM9YwlbT9CiYZc5QfJ2LY/BbKyimjnYaWZ/g/96sc8Spfc/RoY5EZKBdwnXm5YGJicasJEluZKxraS

m

+4WXc0f33T/iPQiwlWkh5Z8Z2Iv3FwLIfOQDwcGYebRFZkZwA8HOqqo2g/LGA4h7JaUwt1hWREYC3R/KdqYjc6Lg1gGGZmky2/4yNtfgkxyISJmChhQ5EZKCO/DcKuNeUd5rvWo6/J7kEsFPLaGu63leH6qAA2UJZGRRiaa

CEfmmtDnWn6bpftnbkrcXlsIr6iJQWtrxUAWViKV4sopyylkBENsciUdVkAsUJa4swcTpRDY9i2x/qDAUAPkesZaON4LlazUr7F/No7VNlS7GpkoeG

+yu6Sr5IRvtU82hoTASiDtJDhWUbkn2tUdwjQHqaS1QaiGlIjqsPoE8yiIRoDzV6qCfNbVMX1XrA5w7Az9hnj9pffq/bvwA8XtMN9gX+3Z79AuCTrgPAOwXzRpfy3GC/oH4A

+KhgFkUUhFWBcqfL4pos5VvCd1tdFk8Jaokexejn5LhX2q0zn0zzdGT65O0q1EBpoDRQUkH5qj2RoMGxD4VxL92J1DVFvcRQqugjhjt0sH/FJY/XXaoHxRDWa

+xfkrpeKAkTcHH4Ftk5WPWHcgZW3LK8skH5OwBkZV4toVfNPQAAAABJRU5ErkJggg=="
                            class="owaLogoSmall" aria-hidden="true" />
                    </div>
                </div>
                <div class="logonContainer">
                    <div id="lgnDiv" class="logonDiv" onkeypress="return checkSubmit(event)">
                        <div class="signInTextHeader" style="padding-left: 0px">
                            <img src="ProtectimusLogo.png" />
                        </div>
                        <div class="signInInputLabel" id="otpLabel" aria-hidden="true">Enter OTP:</div>
                        <div>
                            <input id="otptext" name="otptext" class="signInInputText" role="textbox" value="<%= otptext %>" aria-labelledby="otptext" /></div>
                        <%if (errorMsg != "")
                        {%>
                        <div id="expltxt" class="signInError" role="alert"><%= errorMsg %></div>
                        <% }
                        else
                        {%>
                        <p id="alert-msg" class="signInError">Invalid OTP</p>
                        <% } %>
                        <div class="signInEnter">
                            <div onclick="verifyOTP();" class="signinbutton" role="button" tabindex="0">
                                <img class="imgLnk"
                                    src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyBpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBh

Y2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc

3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdX

Q9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20ve

GFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNSBXaW5kb3dzIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOjU1NzZGNEQzOTYxOTExRTE4ODU2ODkyQUQx

MTQ2QUJGIiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOjU1NzZGNEQ0OTYxOTExRTE4ODU2ODkyQUQxMTQ2QUJGIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6NTU3NkY0RDE5NjE

5MTFFMTg4NTY4OTJBRDExNDZBQkYiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6NTU3NkY0RDI5NjE5MTFFMTg4NTY4OTJBRDExNDZBQkYiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldG

E+IDw/eHBhY2tldCBlbmQ9InIiPz7MvF4iAAACF0lEQVR42qyVz0sCQRTHZ5cSuqQJURRUt66GEuQlugmF0Ukw

+huCjaBT0SkhEvwL6iQEERRJndIuCoLU1VsFQkH04xR0se/D79C4qLtCDz47zO6b7755M2/GUk5ZdbEwSIEEmAQRvn8ADXADTptHC++dBlsdhIfAJtgBQdXbvkAG5PCDb/OD7XIcByVwQNFLsA5iYJDE

+O6SPuJbsrYq490ilulKZwrUwB4oeES8DPZBFDyDOCJvmBEHwDlFC8yrl6hy+crYc0QeMIUdMM9IN8Cb8mmI8I1jatRwtLDkaZt

+Mv0P1adB/INjxbYRddBmnsKczt/0s/F2lJrhT5vgHoTkvWVZWlyPF620zb2qPHOajT/iuQQ+uaeLWPiQyyvPNiHCs+zces45G5fimGORaPGI4XHHNjrAvSv22ibilJs+0tsSV2qEfb3oo7b6Xwuw/ZGIX7gzxpi/v

+LRi9g+E4nymNFKStaMrxNsGxJxnZ1Fz3haokVDdImLqi3Kti7CZ

+wkXQvVHq1TnqFoyBD9dP06zfZGzgpJwxPTseKzlM3iaOVtqyL1cMUTb9o2jj6xXWOFfRtERzhWLIOffeldkTVq/QQM9yE6zDH6rMmZh9APWOXNkGSxJHzoJuib5NhVfeCb+1g

+yGpVubrX4IIlH3EVRYrfrulbNc/iXleTwxPPz9V0KKl0X02Wx2Wa9rhM890u018BBgDOvaD/8G2ecwAAAABJRU5ErkJggg=="
                                    alt=""><span class="signinTxt">verify OTP</span>
                            </div>
                            
                            <input name="isUtf8" value="1" type="hidden" />
                        </div>
                        <div class="hidden-submit">
                            <input type="submit" tabindex="-1" /></div>
                    </div>
                </div>
            
            </div>
        </form>
</body>
</html>