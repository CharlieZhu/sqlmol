
Partial Class _Default
    Inherits System.Web.UI.Page

    Protected theMOL As String = ""
    Protected theSMI As String = ""

    Protected Function despictURL(ByVal smi As String) As String
        Return "http://www.daylight.com/dayhttp/smi2gif?smiles=" + Server.UrlEncode(smi) + _
               "&width=120&height=120&colormode=COW" + "&highlight=" + Server.UrlEncode(Me.theSMI)
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Me.IsPostBack = True And Me.tx_mol.Value <> "" Then
            Me.theMOL = Me.tx_mol.Value
            Me.theSMI = Me.tx1.Value
            Me.tx_debug.Text = ":::" + Me.theSMI

            Me.SqlDataSourceSMIs.SelectCommandType = SqlDataSourceCommandType.StoredProcedure
            Me.SqlDataSourceSMIs.SelectCommand = "search_by_smi"
            Me.SqlDataSourceSMIs.SelectParameters("smi").DefaultValue = Me.theSMI
            Me.Repeater1.DataBind()

        End If
    End Sub

    Protected Sub RetrieveAll_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles RetrieveAll.Click
        Me.SqlDataSourceSMIs.SelectCommandType = SqlDataSourceCommandType.Text
        Me.SqlDataSourceSMIs.SelectCommand = "select * from sqlmol_compound"
        Me.Repeater1.DataBind()
    End Sub
End Class
