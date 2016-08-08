<%@ Page Language="VB" AutoEventWireup="false" CodeFile="Default.aspx.vb" Inherits="_Default" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>SQLMOL Web interface</title>

    <script src="http://www.google.com/jsapi" type="text/javascript"></script>

    <script type="text/javascript">
        // Load jQuery
        google.load("jquery", "1");
    </script>

    <script type="text/javascript">
        function act() {
            var smiles = document.JME.smiles();
            var mol = document.JME.jmeFile();
            $("#<%=Me.tx1.ClientID %>").attr("value", smiles);
            $("#<%=Me.tx_mol.ClientID %>").attr("value", mol);
            //alert(mol);
            //alert($("#tx1").attr("value"));
            //$('#tx1').value = (document.applets[0].MolFile()); alert(document.tx1.value);
            return false;
        }
    </script>
    <style type="text/css">
        .mblock{ 
            font-family: Consolas, Courier New; 
            font-size: 8pt;
            border-bottom: solid 1px black;
            border-right:  solid 2px #CCCCCC;
            float:left;
            margin: 2px; padding: 2px;
        }
    </style>
</head>
<body>
    <form id="form1" runat="server">
    <div>
        <div style="float: left">
            <applet name="JME" code="JME.class" archive="JME.jar" width="350" height="350">
                <param name="jme" value="<%=me.theMOL %>" />
            </applet>
            <br />
            <font face="arial,helvetica,sans-serif"><small><a href="http://www.molinspiration.com/jme/index.html">
                JME Editor</a> courtesy of Peter Ertl, Novartis</small></font>
            <br />
            <asp:Label runat="server" ForeColor="Red" ID="tx_debug"></asp:Label>
            <br />
            <input type="submit" value="submit" name="submit" onclick="javascript:act();" />
            <asp:Button runat="server" Text="Retrieve all" ID="RetrieveAll" OnClientClick='javascript:$("#<%=Me.tx_mol.ClientID %>").attr("value", "");'/>
            <br />
            You need to keep connection to internet when using this program.
            <ul>
                <li>jQuery lib hosted on Google Code.</li>
                <li>Daylight smi2gif service.</li>
            </ul>
        </div>
        <asp:HiddenField runat="server" ID="tx1" />
        <asp:HiddenField runat="server" ID="tx_mol" />
        <asp:Repeater ID="Repeater1" runat="server" DataSourceID="SqlDataSourceSMIs">
            <ItemTemplate>
                <div class="mblock">
                <img src="<%#me.despictURL(Eval("smiles")) %>" alt="<%#Eval("smiles") %>" title="<%#Eval("smiles") %>" />
                <br />
                <%#Eval("compoundid")%>::<%#Eval("smiles") %>
                </div>
            </ItemTemplate>
        </asp:Repeater>
        <asp:SqlDataSource ID="SqlDataSourceSMIs" runat="server" ConnectionString="<%$ ConnectionStrings:SQLMOLConnectionString %>"
            SelectCommand="search_by_smi" SelectCommandType="StoredProcedure">
            <SelectParameters>
                <asp:Parameter Name="smi" Type="String" />
            </SelectParameters>
        </asp:SqlDataSource>
    </div>
    </form>
</body>
</html>
