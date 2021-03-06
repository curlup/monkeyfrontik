<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" id="style" xmlns:str="http://exslt.org/strings"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output omit-xml-declaration="yes" method="xml" indent="no" encoding="UTF-8"
                media-type="text/html" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
                doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" version="1.1"/>

    <xsl:variable name="highlight-text">
        <xsl:if test="contains(/log/@mode, '@')">
            <xsl:value-of select="substring(/log/@mode, 2)"/>
        </xsl:if>
    </xsl:variable>

    <xsl:variable name="xsltprofile-sort">
        <xsl:choose>
            <xsl:when test="/log/@xsltprofile != ''">
                <xsl:value-of select="/log/@xsltprofile"/>
            </xsl:when>
            <xsl:otherwise>time</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:template match="/log">
        <html>
            <head>
                <title>Status
                    <xsl:value-of select="@code"/>
                </title>
                <xsl:apply-templates select="." mode="css"/>
                <xsl:apply-templates select="." mode="js"/>
            </head>
            <body>
                <div class="textentry m-textentry_title">
                    requestid: <xsl:value-of select="@request-id"/>,
                    status:
                    <xsl:value-of select="@code"/>
                </div>
                <xsl:apply-templates select="entry[stattracelink]"/>
                <xsl:apply-templates select="entry[profile]"/>
                <xsl:apply-templates select="entry[not(profile)]"/>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="entry[stattracelink]">
        <div class="textentry m-textentry_title">
            Trace link: <a class="servicelink" href="{stattracelink}" target="_blank">
                <xsl:value-of select="stattracelink"/>
            </a>
        </div>
    </xsl:template>

    <xsl:template match="entry[profile]">
        <div class="textentry">
            <xsl:apply-templates select="profile" mode="xsltprofile"/>
        </div>
    </xsl:template>

    <xsl:template match="profile" mode="xsltprofile">
        <table class="xsltprofile">
            <thead><tr>
                <xsl:apply-templates select="template[1]/@*[name()!='rank']" mode="xsltprofile"/>
            </tr></thead>
            <tbody>
                <xsl:apply-templates select="template" mode="xsltprofile">
                    <xsl:sort select="@*[name()=$xsltprofile-sort][1]" data-type="number" order="descending"/>
                </xsl:apply-templates>
            </tbody>
        </table>
    </xsl:template>

    <xsl:template match="@*" mode="xsltprofile">
        <th>
            <xsl:value-of select="name()"/>
        </th>
    </xsl:template>

    <xsl:template match="@*[name()='time']" mode="xsltprofile">
        <th>
            <xsl:value-of select="name()"/>
            (<xsl:value-of select="sum(ancestor::profile/template/@time)"/>)
        </th>
    </xsl:template>

    <xsl:template match="template" mode="xsltprofile">
        <tr>
            <xsl:apply-templates select="@*[name()!='rank']" mode="xsltprofile-td"/>
        </tr>
    </xsl:template>

    <xsl:template match="@*" mode="xsltprofile-td">
        <td><xsl:value-of select="."/></td>
    </xsl:template>

    <xsl:template match="entry[contains(@msg, 'finish group') and /log/@mode != 'full']"/>

    <xsl:template match="entry">

        <xsl:variable name="highlight">
            <xsl:if test="$highlight-text != '' and contains(@msg, $highlight-text)">m-textentry__head_highlight</xsl:if>
        </xsl:variable>

        <div class="textentry">
            <pre class="textentry__head {$highlight}">
                <span title="{@msg}">
                    <xsl:value-of select="@msg"/>
                </span>
            </pre>
            <xsl:apply-templates select="@exc_text"/>
        </div>
    </xsl:template>

    <xsl:template match="@exc_text">
        <pre class="ecxeption">
            <xsl:value-of select="."/>
        </pre>
    </xsl:template>

    <xsl:template match="entry[response]">
        <xsl:variable name="status">
            <xsl:if test="response/code != 200">error</xsl:if>
        </xsl:variable>
        <xsl:variable name="text">
            <xsl:value-of select="."/>
        </xsl:variable>
        <xsl:variable name="highlight">
            <xsl:if test="$highlight-text != '' and contains($text, $highlight-text)">m-textentry__head_highlight
            </xsl:if>
        </xsl:variable>

        <div class="textentry m-textentry__expandable">
            <div onclick="toggle(this.parentNode)" class="textentry__head textentry__switcher {$status} {$highlight}">
                <span title="{@msg}" class="textentry__head__expandtext">
                    <span class="time">
                        <xsl:value-of select="response/request_time"/>
                        <xsl:text>ms </xsl:text>
                    </span>
                    <xsl:value-of select="response/code"/>
                    <xsl:text> </xsl:text>
                    <xsl:value-of select="request/method"/>
                    <xsl:text> </xsl:text>
                    <xsl:value-of select="request/url"/>
                </span>
            </div>
            <div class="details">
                <xsl:apply-templates select="request"/>
                <div>---------------------------</div>
                <xsl:apply-templates select="response"/>
            </div>
        </div>
    </xsl:template>

    <xsl:template match="request">
        <div>
            <a class="servicelink" href="{url}" target="_blank">
                <xsl:value-of select="url"/>
            </a>
        </div>
        <xsl:apply-templates select="headers[header]"/>
        <xsl:apply-templates select="cookies[cookie]"/>
        <xsl:apply-templates select="params[param]"/>
        <xsl:apply-templates select="body[param]" mode="params"/>
        <xsl:apply-templates select="body[not(param)]"/>
    </xsl:template>

    <xsl:template match="response">
        <xsl:apply-templates select="error"/>
        <xsl:apply-templates select="headers[header]"/>
        <xsl:apply-templates select="body"/>
    </xsl:template>

    <xsl:template match="error[text() = 'None']"/>

    <xsl:template match="error">
        <div class="error">
            <xsl:value-of select="."/>
        </div>
    </xsl:template>

    <xsl:template match="body"/>

    <xsl:template match="body[text()]">
        <div class="delimeter">body</div>
        <div class="body">
            <xsl:value-of select="."/>
        </div>
    </xsl:template>

    <xsl:template match="body[node()]">
        <div class="delimeter">body</div>
        <div class="coloredxml">
            <xsl:apply-templates select="node()" mode="color-xml"/>
        </div>
    </xsl:template>

    <xsl:template match="body[contains(@content_type, 'text/html')]">
        <xsl:variable name="id" select="generate-id(.)"/>
        <div class="delimeter">body</div>
        <div id="{$id}"><![CDATA[]]></div>
        <script>
            doiframe('<xsl:value-of select="$id"/>', '<xsl:value-of select="."/>');
        </script>
    </xsl:template>

    <xsl:template match="body[contains(@content_type, 'json')]">
        <div class="delimeter">body</div>
        <pre><xsl:value-of select="."/></pre>
    </xsl:template>

    <xsl:template match="body" mode="params">
        <div class="params">
            <div class="delimeter">body</div>
            <xsl:apply-templates select="param"/>
        </div>
    </xsl:template>

    <xsl:template match="headers">
        <div class="headers">
            <div class="delimeter">headers</div>
            <xsl:apply-templates select="header"/>
        </div>
    </xsl:template>

    <xsl:template match="header">
        <div><xsl:value-of select="@name"/>: &#160;<xsl:value-of select="."/>
        </div>
    </xsl:template>

    <xsl:template match="cookies">
        <div class="cookies">
            <div class="delimeter">cookies</div>
            <xsl:apply-templates select="cookie"/>
        </div>
    </xsl:template>

    <xsl:template match="cookie">
        <div><xsl:value-of select="@name"/>&#160;=&#160;<xsl:value-of select="."/>
        </div>
    </xsl:template>

    <xsl:template match="params">
        <div class="params">
            <div class="delimeter">params</div>
            <xsl:apply-templates select="param"/>
        </div>
    </xsl:template>

    <xsl:template match="param">
        <table>
            <tr>
                <td class="param__name">
                    <xsl:value-of select="@name"/><xsl:text>&#160;=&#160;</xsl:text>
                </td>
                <td class="param__value">
                    <xsl:apply-templates select="str:tokenize(string(.), '&#0013;&#0010;')" mode="line"/>
                </td>
            </tr>
        </table>
    </xsl:template>


    <xsl:template match="log" mode="css">
        <style>
            * {font-size: 12px;}

            body, pre{
                font-family: Tahoma,sans-serif;
            }
            pre{
                margin:0;
            }
            .textentry{
                padding-left:20px;
                padding-right:20px;
                margin-bottom:2px;
            }
                .m-textentry__expandable{
                    padding-top:3px;
                    padding-bottom:3px;
                    background:#fffccf;
                }
                .m-textentry_title{
                    font-size:1.3em;
                    margin-bottom:.5em;
                }
                .textentry__head{
                }
                    .m-textentry__head_highlight{
                        font-weight:bold;
                    }
                    .textentry__head__expandtext{
                        border-bottom:1px dotted #666;
                    }
                .textentry__switcher{
                    height:1.3em;
                    overflow:hidden;
                    cursor:pointer;
                }

            .xsltprofile {
                border-collapse: collapse;
            }
            .xsltprofile tbody tr:hover {
                background: #ffcccc
            }

            .xsltprofile td, .xsltprofile th {
                padding: 2px 5px;
                border-bottom: 1px solid #aaa;
                text-align: left;
            }

            .headers{
            }
            .details{
                display:none;
                margin-bottom:15px;
            }
                .m-details_visible{
                    display:block;
                }

            .param__name{
                vertical-align:top;
            }
            .param__value{
                vertical-align:top;
            }
            .servicelink{
                color:#666;
                font-size:12px;
            }
            .coloredxml__line{
                padding: 0px 0px 0px 20px;
            }
            .coloredxml__tag, .coloredxml__param{
                color: #9c0628;
            }
            .coloredxml__value{
            }
            .coloredxml__comment{
                color: #063;
                display: block;
                padding: 0px 0px 0px 30px;
                padding-top: 20px;
            }
            .time{
                display:inline-block;
                width:4em;
            }
            .error{
                color:red;
            }
            .delimeter{
                margin-top:10px;
                font-size:12px;
                color:#999;
            }
            .ecxeption{
                margin-bottom:20px;
                color:#c00;
            }
            .iframe{
                width:100%;
                height:500px;
                background:#fff;
                border:1px solid #ccc;
                margin-top:5px;
                box-shadow:1px 1px 8px #aaacca;
                -moz-box-shadow:1px 1px 8px #aaacca;
                -webkit-box-shadow:1px 1px 8px #aaacca;
            }
        </style>
    </xsl:template>

    <xsl:template match="log" mode="js">
        <script>
            function toggle(entry){
                var head = entry.querySelector('.textentry__head');
                if (head.className.indexOf('m-textentry__switcher_expand') != -1)
                    head.className = head.className.replace(/m-textentry__switcher_expand/, '');
                else{
                    head.className = head.className + ' m-textentry__switcher_expand';
                }
                var details = entry.querySelector('.details')
                if (details.className.indexOf('m-details_visible') != -1)
                    details.className = details.className.replace(/m-details_visible/, '');
                else{
                    details.className = details.className + ' m-details_visible';
                }
            }
            function doiframe(id, text){
                var iframe = window.document.createElement('iframe');
                iframe.className = 'iframe'
                var html = text
                    .replace(/&lt;/g, '<xsl:text disable-output-escaping="yes">&lt;</xsl:text>')
                    .replace(/&gt;/g, '<xsl:text disable-output-escaping="yes">&gt;</xsl:text>')
                    .replace(/&amp;/g, '<xsl:text disable-output-escaping="yes">&amp;</xsl:text>');
                window.document.getElementById(id).appendChild(iframe);
                var document = iframe.contentWindow.document;
                document.open();
                document.write(html);
                //document.close();
            }
        </script>
    </xsl:template>

    <xsl:template match="*" mode="color-xml">
        <div class="coloredxml__line">
            <xsl:text>&lt;</xsl:text>
            <span class="coloredxml__tag">
                <xsl:value-of select="name()"/>
            </span>

            <xsl:for-each select="@*">
                <xsl:text> </xsl:text>
                <span class="coloredxml__param">
                    <xsl:value-of select="name()"/>
                </span>
                <xsl:text>="</xsl:text>
                <span class="coloredxml__value">
                    <xsl:if test="not(string-length(.))">
                        <xsl:text> </xsl:text>
                    </xsl:if>
                    <xsl:value-of select="."/>
                </span>
                <xsl:text>"</xsl:text>
            </xsl:for-each>

            <xsl:choose>
                <xsl:when test="node()">
                    <xsl:text>&gt;</xsl:text>
                    <xsl:apply-templates select="node()" mode="color-xml"/>
                    <xsl:text>&lt;/</xsl:text>
                    <span class="coloredxml__tag">
                        <xsl:value-of select="name()"/>
                    </span>
                    <xsl:text>&gt;</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>/&gt;</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </div>
    </xsl:template>

    <xsl:template match="text()" mode="color-xml">
        <span class="coloredxml__value">
            <xsl:apply-templates select="str:tokenize(string(.), '&#0013;&#0010;')" mode="line"/>
        </span>
    </xsl:template>

    <xsl:template match="token[text() != '']" mode="line">
        <xsl:if test="position() != 1">
            <br/>
        </xsl:if>
        <xsl:value-of select="."/>
    </xsl:template>

    <xsl:template match="comment()" mode="color-xml">
        <span class="coloredxml__comment">
            &lt;!--<xsl:value-of select="."/>--&gt;
        </span>
    </xsl:template>
</xsl:stylesheet>
