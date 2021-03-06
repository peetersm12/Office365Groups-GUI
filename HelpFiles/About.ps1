Function Open-About {
	$rs=[RunspaceFactory]::CreateRunspace()
	$rs.ApartmentState = "STA"
	$rs.ThreadOptions = "ReuseThread"
	$rs.Open()
	$ps = [PowerShell]::Create()
	$ps.Runspace = $rs
    $ps.Runspace.SessionStateProxy.SetVariable("pwd",$pwd)
	[void]$ps.AddScript({ 
[xml]$xaml = @"
<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
    x:Name='AboutWindow' Title='About' Height = '240' Width = '350' ResizeMode = 'NoResize' WindowStartupLocation = 'CenterScreen' ShowInTaskbar = 'False'>    
        <Window.Background>
        <LinearGradientBrush StartPoint='0,0' EndPoint='0,1'>
            <LinearGradientBrush.GradientStops> <GradientStop Color='#C4CBD8' Offset='0' /> <GradientStop Color='#E6EAF5' Offset='0.2' /> 
            <GradientStop Color='#CFD7E2' Offset='0.9' /> <GradientStop Color='#C4CBD8' Offset='1' /> </LinearGradientBrush.GradientStops>
        </LinearGradientBrush>
    </Window.Background>     
    <StackPanel>
            <Label FontWeight = 'Bold' FontSize = '20'>About PowerShell Office 365 Groups </Label>
            <Label FontWeight = 'Bold' FontSize = '16'>Version: 1.0.0 </Label>
            <Label FontWeight = 'Bold' FontSize = '16'>Created By: Maarten Peeters </Label>
            <Label Padding = '10'> <Hyperlink x:Name = 'AuthorLink'> http://www.sharepointfire.com </Hyperlink> </Label>
			<Label FontWeight = 'Bold' FontSize = '16'>Based on  PoshPAIG tool by: Boe Prox </Label>
			<Label Padding = '10'> <Hyperlink x:Name = 'ReferenceLink'> https://learn-powershell.net/ </Hyperlink> </Label>
            <Button x:Name = 'CloseButton' Width = '100'> Close </Button>
    </StackPanel>
</Window>
"@
#Load XAML
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$AboutWindow=[Windows.Markup.XamlReader]::Load( $reader )


#Connect to Controls
$CloseButton = $AboutWindow.FindName("CloseButton")
$AuthorLink = $AboutWindow.FindName("AuthorLink")
$ReferenceLink = $AboutWindow.FindName("ReferenceLink")

#Link Event
$AuthorLink.Add_Click({
    Start-Process "http://www.sharepointfire.com"
    })
	
#Link Event
$ReferenceLink.Add_Click({
    Start-Process "https://learn-powershell.net"
    })	

$CloseButton.Add_Click({
    $AboutWindow.Close()
    })

#Show Window
[void]$AboutWindow.showDialog()
}).BeginInvoke()
}