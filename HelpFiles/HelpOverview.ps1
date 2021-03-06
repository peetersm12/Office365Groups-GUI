Function Open-Help {
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
    x:Name='Window' Title='Help For PowerShell Office 365 Groups GUI' Height = '600' Width = '800' WindowStartupLocation = 'CenterScreen' 
    ResizeMode = 'NoResize' ShowInTaskbar = 'True' >    
    <Window.Background>
        <LinearGradientBrush StartPoint='0,0' EndPoint='0,1'>
            <LinearGradientBrush.GradientStops> <GradientStop Color='#C4CBD8' Offset='0' /> <GradientStop Color='#E6EAF5' Offset='0.2' /> 
            <GradientStop Color='#CFD7E2' Offset='0.9' /> <GradientStop Color='#C4CBD8' Offset='1' /> </LinearGradientBrush.GradientStops>
        </LinearGradientBrush>
    </Window.Background>    
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width ='30*'> </ColumnDefinition>
            <ColumnDefinition Width ='Auto'> </ColumnDefinition>
            <ColumnDefinition Width ='75*'> </ColumnDefinition>
        </Grid.ColumnDefinitions>
        <TreeView Name = 'HelpTree' FontSize='10pt'>
            <TreeViewItem x:Name = 'RequirementsView' Header = 'Requirements' />  
			<TreeViewItem Header = 'Connect to Office 365' />
			<TreeViewItem Header = 'Actions' />
			<TreeViewItem Header = 'Reporting' />
			<TreeViewItem Header = 'Keyboard Shortcuts' /> 
        </TreeView>
        <GridSplitter Grid.Column='1' Width='6' HorizontalAlignment = 'Center' VerticalAlignment = 'Stretch'>
        </GridSplitter>
        <Frame Name = 'Frame' Grid.Column = '2'>
            <Frame.Content>
            <Page Title = "Home">
                <FlowDocumentReader>
                    <FlowDocument>
                        <Paragraph FontSize = "20">
                            <Bold> PowerShell Restore Office 365 GUI </Bold>
                        </Paragraph>
						<Paragraph>
                            Please click on one of the links on the left to view the various help items.
                        </Paragraph>
                        <Paragraph> <Image Source = '$pwd\HelpFiles\Images\FrontWindow.png' /> </Paragraph>
                    </FlowDocument>
                </FlowDocumentReader>
            </Page>
            </Frame.Content>
        </Frame>
    </Grid>
</Window>

"@
#Load XAML
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$HelpWindow=[Windows.Markup.XamlReader]::Load( $reader )

#Requirements Help
[xml]$data = @"
<Page
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title = "Requirements">    
    <FlowDocumentReader>
        <FlowDocument>
            <Paragraph FontSize = "18" TextAlignment="Center">   
                <Bold> Requirements for the Office 365 GUI </Bold>
            </Paragraph>       
			<Paragraph>
				You will need the below requirements before you can use this tool:
			</Paragraph>
			<List MarkerStyle="decimal">
				<ListItem><Paragraph>At least Exchange and User administrator permissions in Office 365. Being Global Administrator will certainly do the job.</Paragraph></ListItem>
				<ListItem><Paragraph>You will need to install the preview version of the Azure AD Module to be able to restore Office 365 Groups.
					The Azure AD preview module can be imported using install-module AzureADPreview.
					You can find more information at <Hyperlink x:Name = 'AzureADPreview'> https://docs.microsoft.com/en-us/powershell/azure/install-adv2?view=azureadps-2.0 </Hyperlink>
				</Paragraph></ListItem>
			</List>
        </FlowDocument>
    </FlowDocumentReader>
</Page>
"@
$reader=(New-Object System.Xml.XmlNodeReader $data)
$Requirements=[Windows.Markup.XamlReader]::Load( $reader )

#InstallPatches Help
[xml]$data = @"
<Page
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title = "Connect to Office 365">
    <FlowDocumentReader ViewingMode = 'Scroll'>
        <FlowDocument>
            <Paragraph FontSize = "18" TextAlignment="Center">   
                <Bold> Connect to Office 365 </Bold>
            </Paragraph>
            <Paragraph>
                Before you can begin you first need to connect to Office 365.
            </Paragraph>   
            <Paragraph>
                Make sure the drop down selection is saying 'Connect to Office 365' and press the play button
            </Paragraph>
            <Paragraph>
				<Image Source = '$pwd\HelpFiles\Images\connect1.png' />
            </Paragraph>  
            <Paragraph>
                Then fill in your username and credential to log in to Office 365
            </Paragraph>
            <Paragraph>
				<Image Source = '$pwd\HelpFiles\Images\connect2.png' />
            </Paragraph>
            <Paragraph>
                Connection is succesfull when you see the green message
            </Paragraph>
            <Paragraph>
				<Image Source = '$pwd\HelpFiles\Images\connect3.png' />
            </Paragraph>			
        </FlowDocument>
    </FlowDocumentReader>
</Page>
"@
$reader=(New-Object System.Xml.XmlNodeReader $data)
$ConnecttoOffice365=[Windows.Markup.XamlReader]::Load( $reader )

#ReportingPatches Help
[xml]$data = @"
<Page
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title = "Reporting">    
	<FlowDocumentReader ViewingMode = 'Scroll'>
        <FlowDocument>
            <Paragraph FontSize = "18" TextAlignment="Center">   
                <Bold> Reporting </Bold>
            </Paragraph>
            <Paragraph>
                You can at any time create a .csv or .html of the contents in the listview
            </Paragraph>   
            <Paragraph>
                The output from the .csv will look like the below
			</Paragraph> 
			<Paragraph>
				<Image Source = '$pwd\HelpFiles\Images\reportCSV.png' />
            </Paragraph>  
            <Paragraph>
                The output from the .html will look like the below
			</Paragraph>
            <Paragraph>
				<Image Source = '$pwd\HelpFiles\Images\reportHTML.png' />
            </Paragraph>            
        </FlowDocument>
    </FlowDocumentReader>
</Page>
"@
$reader=(New-Object System.Xml.XmlNodeReader $data)
$Reports=[Windows.Markup.XamlReader]::Load( $reader )

#Actions Help
[xml]$data = @"
<Page
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title = "Actions">    
	<FlowDocumentReader ViewingMode = 'Scroll'>
        <FlowDocument>
            <Paragraph FontSize = "18" TextAlignment="Center">   
                <Bold> Actions </Bold>
            </Paragraph>
            <List>
                <ListItem>
					<Paragraph> 
						<Bold>Get Office 365 Groups:</Bold>
					</Paragraph>
					<Paragraph>
						This action will result in a list of all the Office 365 Groups present on the Office 365 tenant.
					</Paragraph>
				</ListItem>
                <ListItem>
					<Paragraph> 
						<Bold>Get deleted Office 365 Groups:</Bold>
					</Paragraph>
					<Paragraph>
						This action will result in a list of all the deleted Office 365 groups present on the Office 365 tenant.
					</Paragraph>
				</ListItem>
                <ListItem>
					<Paragraph> 
						<Bold>Restore Office 365 Groups:</Bold>
					</Paragraph>
					<Paragraph>
						This action can be executed after running the action to list all the deleted groups. The selection will be restored in batches of two items.
					</Paragraph>
				</ListItem>			
            </List>           
        </FlowDocument>
    </FlowDocumentReader>
</Page>
"@
$reader=(New-Object System.Xml.XmlNodeReader $data)
$Actions=[Windows.Markup.XamlReader]::Load( $reader )

#Keyboard Shortcuts Help
[xml]$data = @"
<Page
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title = "Keyboard Shortcuts">    
    <FlowDocumentReader>
        <FlowDocument>
            <Paragraph FontSize = "18" TextAlignment="Center">   
                <Bold> List of Keyboard Shortcuts </Bold>
            </Paragraph>
            <List>
                <ListItem><Paragraph> <Bold>F1:</Bold> Display Help </Paragraph></ListItem>
                <ListItem><Paragraph> <Bold>F5:</Bold> Run the selected command.</Paragraph></ListItem>
                <ListItem><Paragraph> <Bold>F8:</Bold> Run a select report to generate </Paragraph></ListItem>
            </List>
        </FlowDocument>
    </FlowDocumentReader>
</Page>
"@
$reader=(New-Object System.Xml.XmlNodeReader $data)
$KeyboardShortcuts=[Windows.Markup.XamlReader]::Load( $reader )

#Connect to all controls
$AzureADPreview = $Requirements.FindName("AzureADPreview")
$HelpTree = $HelpWindow.FindName("HelpTree")
$Frame = $HelpWindow.FindName("Frame")
$RequirementsView = $HelpWindow.FindName("RequirementsView")

##Events
#HelpTree event
$HelpTree.Add_SelectedItemChanged({
    Switch ($This.SelectedItem.Header) {
        "Requirements" {
            $Frame.Content = $Requirements        
            }
        "Connect to Office 365" {
            $Frame.Content = $ConnecttoOffice365        
            }
        "Actions" {
            $Frame.Content = $Actions
            }			
        "Reporting" {
            $Frame.Content = $Reports
            }
        "Keyboard Shortcuts" {
            $Frame.Content = $KeyboardShortcuts
			}  
		}
    })
	
#PsexecLink Event
$AzureADPreview.Add_Click({
    Start-Process "https://docs.microsoft.com/en-us/powershell/azure/install-adv2?view=azureadps-2.0"
    })

[void]$HelpWindow.showDialog()

}).BeginInvoke()
}