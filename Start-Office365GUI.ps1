<#
.SYNOPSIS
        This GUI will let you view active and deleted Office365 Groups and restore deleted groups
.DESCRIPTION
        This GUI tool was inspired by the PoshPAIG tool created by Boe Prox.  
.LINK
    Maarten Peeters Blog
        - http://www.sharepointfire.com
    Boe Prox Blog
        - https://learn-powershell.net
.NOTES
        Author:     M. Peeters
        Date:       30/5/2017
        PS Ver.:    5.0
        Script Ver: 1.0

        Change log:
            v0.1 Stripped PoshPAIG tool from not needed functions
			v0.2 Changed GUI to reflect needed functionality
			v0.3 Added functionality to connect to Office 365, retrieve groups, retrieve deleted groups and restore these groups
			v0.4 Edited help files
			v1.0 Finilized script
#>

#region Synchronized Collections
$uiHash = [hashtable]::Synchronized(@{})
$runspaceHash = [hashtable]::Synchronized(@{})
$jobs = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList))
$jobCleanup = [hashtable]::Synchronized(@{})
#endregion

#region Startup Checks and configurations
#Validate user is an Administrator
Write-Verbose "Checking Administrator credentials"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You are not running this as an Administrator!`nRe-running script and will prompt for administrator credentials."
    Start-Process -Verb "Runas" -File PowerShell.exe -Argument "-STA -noprofile -file `"$($myinvocation.mycommand.definition)`""
    Break
}

#Ensure that we are running the GUI from the correct location
Set-Location $(Split-Path $MyInvocation.MyCommand.Path)
$Global:Path = $(Split-Path $MyInvocation.MyCommand.Path)
Write-Debug "Current location: $Path"

#Determine if this instance of PowerShell can run WPF 
Write-Verbose "Checking the apartment state"
If ($host.Runspace.ApartmentState -ne "STA") {
    Write-Warning "This script must be run in PowerShell started using -STA switch!`nScript will attempt to open PowerShell in STA and run re-run script."
    Start-Process -File PowerShell.exe -Argument "-STA -noprofile -WindowStyle hidden -file `"$($myinvocation.mycommand.definition)`""
    Break
}

#Load Required Assemblies
Add-Type –assemblyName PresentationFramework
Add-Type –assemblyName PresentationCore
Add-Type –assemblyName WindowsBase
Add-Type –assemblyName Microsoft.VisualBasic
Add-Type –assemblyName System.Windows.Forms

#DotSource Help script
. ".\HelpFiles\HelpOverview.ps1"

#DotSource About script
. ".\HelpFiles\About.ps1"
#endregion

#Function for Debug output
Function Global:Show-DebugState {
    Write-Debug ("Number of Items: {0}" -f $uiHash.Listview.ItemsSource.count)
    Write-Debug ("First Item: {0}" -f $uiHash.Listview.ItemsSource[0].Computer)
    Write-Debug ("Last Item: {0}" -f $uiHash.Listview.ItemsSource[$($uiHash.Listview.ItemsSource.count) -1].Computer)
    Write-Debug ("Max Progress Bar: {0}" -f $uiHash.ProgressBar.Maximum)
}

#Format and display errors
Function Get-Error {
    Process {
        ForEach ($err in $error) {
            Switch ($err) {
                {$err -is [System.Management.Automation.ErrorRecord]} {
                        $hash = @{
                        Category = $err.categoryinfo.Category
                        Activity = $err.categoryinfo.Activity
                        Reason = $err.categoryinfo.Reason
                        Type = $err.GetType().ToString()
                        Exception = ($err.exception -split ": ")[1]
                        QualifiedError = $err.FullyQualifiedErrorId
                        CharacterNumber = $err.InvocationInfo.OffsetInLine
                        LineNumber = $err.InvocationInfo.ScriptLineNumber
                        Line = $err.InvocationInfo.Line
                        TargetObject = $err.TargetObject
                        }
                    }               
                Default {
                    $hash = @{
                        Category = $err.errorrecord.categoryinfo.category
                        Activity = $err.errorrecord.categoryinfo.Activity
                        Reason = $err.errorrecord.categoryinfo.Reason
                        Type = $err.GetType().ToString()
                        Exception = ($err.errorrecord.exception -split ": ")[1]
                        QualifiedError = $err.errorrecord.FullyQualifiedErrorId
                        CharacterNumber = $err.errorrecord.InvocationInfo.OffsetInLine
                        LineNumber = $err.errorrecord.InvocationInfo.ScriptLineNumber
                        Line = $err.errorrecord.InvocationInfo.Line                    
                        TargetObject = $err.errorrecord.TargetObject
                    }               
                }                        
            }
        $object = New-Object PSObject -Property $hash
        $object.PSTypeNames.Insert(0,'ErrorInformation')
        $object
        }
    }
}

#Report function
Function Start-Report {
    Write-Debug ("Data: {0}" -f $uiHash.ReportComboBox.SelectedItem.Text)
	$reportpath = "$($PSScriptRoot)/report" 
	$date = get-date
	$today = $date.ToString("ddMMyyyy_HHmm")
    Switch ($uiHash.ReportComboBox.SelectedItem.Text) {
        "CSV Report" {
            If ($uiHash.Listview.count -gt 0) { 
                $uiHash.StatusTextBox.Foreground = "Black"
                $savedreport = Join-Path $reportpath "CSVReport_$($today).csv"
                $uiHash.Listview.Items | Export-Csv $savedreport -NoTypeInformation
                $uiHash.StatusTextBox.Text = "Report saved to $savedreport"
			} Else {
                $uiHash.StatusTextBox.Foreground = "Red"
                $uiHash.StatusTextBox.Text = "No report to create!"         
            }
		}
        "HTML Report" {
            If ($uiHash.Listview.count -gt 0) { 
                $uiHash.StatusTextBox.Foreground = "Black"
                $savedreport = Join-Path $reportpath "HTMLReport.html"
				
				$HTMLReport = $uiHash.Listview.Items | ConvertTo-Html `
					-As Table `
					-Fragment `
					-PreContent '<h1>HTMLReport</h1>' | 
                            Out-file $savedreport
                $uiHash.StatusTextBox.Text = "Report saved to $savedreport"
			} Else {
                $uiHash.StatusTextBox.Foreground = "Red"
                $uiHash.StatusTextBox.Text = "No report to create!"         
            }    			
        }
    }
}

#GUI changes when starting action
Function Start-Action{
	param(
		$message
	)
	
	$uiHash.StatusTextBox.Foreground = "Black"
	$uiHash.StatusTextBox.Text = $message	
	$uiHash.RunButton.IsEnabled = $False
	$uiHash.StartImage.Source = "$pwd\Images\Start_locked.jpg"
	$uiHash.CancelButton.IsEnabled = $True
	$uiHash.CancelImage.Source = "$pwd\Images\Stop.jpg" 
}

#GUI changes when action has finished
Function End-Action{
	param(
		$message
	)
	
	$uiHash.StatusTextBox.Foreground = "Green"
	$uiHash.StatusTextBox.Text = $message
	$uiHash.RunButton.IsEnabled = $True
	$uiHash.StartImage.Source = "$pwd\Images\Start.jpg"
	$uiHash.CancelButton.IsEnabled = $False
	$uiHash.CancelImage.Source = "$pwd\Images\Stop_locked.jpg"
}

#GUI changes when action generated error
Function Error-Action{
	param(
		$message
	)
	
	$uiHash.StatusTextBox.Foreground = "red"
	$uiHash.StatusTextBox.Text = $message
	$uiHash.RunButton.IsEnabled = $True
	$uiHash.StartImage.Source = "$pwd\Images\Start.jpg"
	$uiHash.CancelButton.IsEnabled = $False
	$uiHash.CancelImage.Source = "$pwd\Images\Stop_locked.jpg"
}

#start-RunJob function
Function Start-RunJob {
	param(
		$credential
	)
    Write-Debug ("ComboBox {0}" -f $uiHash.RunOptionComboBox.Text)
	$selectedItems = $uiHash.Listview.SelectedItems
	 
	If ($uiHash.RunOptionComboBox.Text -eq 'Connect to Office 365') {

		start-action -message "Connecting to Office 365...Please Wait"
		
		try{	
			$credential = get-credential
			
			$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credential -Authentication Basic –AllowRedirection
			Import-PSSession $Session 
			
			connect-azuread -credential $credential
			
			end-action -message "Connected Succesfully"
		}
		catch{
			error-action -message "Error connecting"
		}			
	}
	elseif ($uiHash.RunOptionComboBox.Text -eq 'Get Office 365 Groups') {
		$clientObservable.Clear()
		start-action -message "Retrieving Office 365 groups...Please Wait" 		
		
		try{
			$groups = get-unifiedgroup
			
			ForEach ($group in $groups) { 
				If (-NOT [System.String]::IsNullOrEmpty($group)) {  
					$clientObservable.Add((
						New-Object PSObject -Property @{
							Name = $group.DisplayName
							Alias = $group.alias
							server = $group.servername	
							AccessType = $group.accesstype
							notes = "Owner = $($group.ManagedByDetails)"
						}
					))     
					Show-DebugState
				}
			}
			
			end-action -message "Retrieved Office 365 groups."		
		}
		catch{
			error-action -message "Error retrieving office 365 groups"	
		}
	}
	ElseIf ($uiHash.RunOptionComboBox.Text -eq 'Get deleted Office 365 Groups') {
		$clientObservable.Clear()
		start-action -message "Retrieving deleted Office 365 groups...Please Wait" 
		
		try{
			$groups = Get-AzureADMSDeletedGroup
			
			ForEach ($group in $groups) { 
				If (-NOT [System.String]::IsNullOrEmpty($group)) {  
					$clientObservable.Add((
						New-Object PSObject -Property @{
							Name = $group.DisplayName
							Alias = $group.MailNickname
							server = ""	
							AccessType = $group.Visibility
							notes = "Deleted on $($group.DeletedDateTime)"
						}
					))     
					Show-DebugState
				}
			}
		
			end-action -message "Retrieved deleted Office 365 groups."
		}
		catch{
			error-action -message "Error retrieving office 365 groups"					
		}		
	}
	ElseIf ($uiHash.RunOptionComboBox.Text -eq 'Restore Office 365 Groups') {
		If (($selectedItems.Count -gt 0)) {
			$uiHash.ProgressBar.Maximum = $selectedItems.count
			write-verbose "Progressbar maximum: $($uiHash.ProgressBar.Maximum)"
			$uiHash.Listview.ItemsSource | ForEach {$_.Notes = $Null} 		
			If ($uiHash.RunOptionComboBox.Text -eq 'Restore Office 365 Groups') {
				start-action -message "Restoring deleted Office 365 groups...Please Wait" 		
				$uiHash.StartTime = (Get-Date)
				
				[Float]$uiHash.ProgressBar.Value = 0
				$scriptBlock = {
					Param (
						$credential,
						$Office365Group,
						$uiHash
					)
					
					$uiHash.ListView.Dispatcher.Invoke("Normal",[action]{ 
						$uiHash.Listview.Items.EditItem($Office365Group)
						$Office365Group.Notes = "Restoring group"
						$uiHash.Listview.Items.CommitEdit()
						$uiHash.Listview.Items.Refresh() 
					}) 				
					
					$Restoringgroup = Get-AzureADMSDeletedGroup | where {$_.displayname -eq $Office365Group.name}
					Restore-AzureADMSDeletedDirectoryObject –Id $Restoringgroup.id

					$restored = $false
					Do {
						$groups = Get-AzureADMSGroup
					
						foreach($group in $groups){
							if ($group.displayname -eq $Office365Group){
								$restored = $true
							}
						}
						
						start-sleep 5
					}
					While ($restored -eq $true)

					$uiHash.ProgressBar.Dispatcher.Invoke("Normal",[action]{
						$Office365Group.Notes = "Completed"
						$uiHash.Listview.Items.CommitEdit()
						$uiHash.Listview.Items.Refresh()
						$uiHash.ProgressBar.value++  
					})
					
					$uiHash.Window.Dispatcher.Invoke("Normal",[action]{
						#Check to see if find job
						If ($uiHash.ProgressBar.value -eq $uiHash.ProgressBar.Maximum) {  
							write-verbose "Completed restore action for selected groups"
							$End = New-Timespan $uihash.StartTime (Get-Date)     
							$uiHash.StatusTextBox.Foreground = "Green"
							$uiHash.StatusTextBox.Text = ("Completed in {0}" -f $end) 
							$uiHash.RunButton.IsEnabled = $True
							$uiHash.StartImage.Source = "$pwd\Images\Start.jpg"
							$uiHash.CancelButton.IsEnabled = $False
							$uiHash.CancelImage.Source = "$pwd\Images\Stop_locked.jpg"  							
						}
					}) 
				}
			
				Write-Verbose ("Creating runspace pool and session states")
				$sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
				$runspaceHash.runspacepool = [runspacefactory]::CreateRunspacePool(1, 2, $sessionstate, $Host)
				$runspaceHash.runspacepool.Open()  
				
				ForEach ($O365group in $selectedItems) {
					$uiHash.Listview.Items.EditItem($O365group)
					$O365group.Notes = "Pending restore"
					$uiHash.Listview.Items.CommitEdit()
					$uiHash.Listview.Items.Refresh() 
					#Create the powershell instance and supply the scriptblock with the other parameters 
					$powershell = [powershell]::Create().AddScript($ScriptBlock).AddArgument($credential).AddArgument($O365group).AddArgument($uiHash)
			   
					#Add the runspace into the powershell instance
					$powershell.RunspacePool = $runspaceHash.runspacepool
			   
					#Create a temporary collection for each runspace
					$temp = "" | Select-Object PowerShell,Runspace,O365group
					$Temp.O365group = $O365group.Name
					$temp.PowerShell = $powershell
			   
					#Save the handle output when calling BeginInvoke() that will be used later to end the runspace
					$temp.Runspace = $powershell.BeginInvoke()
					Write-Verbose ("Adding {0} collection" -f $temp.Name)
					$jobs.Add($temp) | Out-Null                
				}#endregion  			
			}
		}
		Else {
			error-action -message "No groups selected!"
		}
	}
	
	return $credential
}

#Build the GUI
[xml]$xaml = @"
<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
    x:Name='Window' Title='PowerShell Office 365 Groups' WindowStartupLocation = 'CenterScreen' 
    Width = '880' Height = '575' ShowInTaskbar = 'True'>
    <Window.Background>
        <LinearGradientBrush StartPoint='0,0' EndPoint='0,1'>
            <LinearGradientBrush.GradientStops> <GradientStop Color='#C4CBD8' Offset='0' /> <GradientStop Color='#E6EAF5' Offset='0.2' /> 
            <GradientStop Color='#CFD7E2' Offset='0.9' /> <GradientStop Color='#C4CBD8' Offset='1' /> </LinearGradientBrush.GradientStops>
        </LinearGradientBrush>
    </Window.Background> 
    <Window.Resources>        
        <DataTemplate x:Key="HeaderTemplate">
            <DockPanel>
                <TextBlock FontSize="10" Foreground="Green" FontWeight="Bold" >
                    <TextBlock.Text>
                        <Binding/>
                    </TextBlock.Text>
                </TextBlock>
            </DockPanel>
        </DataTemplate>            
    </Window.Resources>    
    <Grid x:Name = 'Grid' ShowGridLines = 'false'>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
            <RowDefinition Height = 'Auto'/>
            <RowDefinition Height = 'Auto'/>
            <RowDefinition Height = '*'/>
            <RowDefinition Height = 'Auto'/>
            <RowDefinition Height = 'Auto'/>
            <RowDefinition Height = 'Auto'/>
        </Grid.RowDefinitions>    
        <Menu Width = 'Auto' HorizontalAlignment = 'Stretch' Grid.Row = '0'>
        <Menu.Background>
            <LinearGradientBrush StartPoint='0,0' EndPoint='0,1'>
                <LinearGradientBrush.GradientStops> <GradientStop Color='#C4CBD8' Offset='0' /> <GradientStop Color='#E6EAF5' Offset='0.2' /> 
                <GradientStop Color='#CFD7E2' Offset='0.9' /> <GradientStop Color='#C4CBD8' Offset='1' /> </LinearGradientBrush.GradientStops>
            </LinearGradientBrush>
        </Menu.Background>
            <MenuItem x:Name = 'FileMenu' Header = '_File'>
                <MenuItem x:Name = 'RunMenu' Header = '_Run' ToolTip = 'Initiate Run operation' InputGestureText ='F5'> </MenuItem>
                <MenuItem x:Name = 'GenerateReportMenu' Header = 'Generate R_eport' ToolTip = 'Generate Report' InputGestureText ='F8'/>
                <Separator />            
                <MenuItem x:Name = 'ExitMenu' Header = 'E_xit' ToolTip = 'Exits the utility.' InputGestureText ='Ctrl+E'/>
            </MenuItem>  		
            <MenuItem x:Name = 'HelpMenu' Header = '_Help'>
                <MenuItem x:Name = 'AboutMenu' Header = '_About' ToolTip = 'Show the current version and other information.'> </MenuItem>
                <MenuItem x:Name = 'HelpFileMenu' Header = 'Restore Office 365 Utility _Help' 
                ToolTip = 'Displays a help file to use this GUI.' InputGestureText ='F1'> </MenuItem>
				<Separator/>
                <MenuItem x:Name = 'ViewErrorMenu' Header = 'View ErrorLog' ToolTip = 'Get error log.'/> 
				<MenuItem x:Name = 'ClearErrorMenu' Header = 'Clear ErrorLog' ToolTip = 'Clears error log.'> </MenuItem>				
            </MenuItem>            
        </Menu>
        <ToolBarTray Grid.Row = '1' Grid.Column = '0'>
        <ToolBarTray.Background>
            <LinearGradientBrush StartPoint='0,0' EndPoint='0,1'>
                <LinearGradientBrush.GradientStops> <GradientStop Color='#C4CBD8' Offset='0' /> <GradientStop Color='#E6EAF5' Offset='0.2' /> 
                <GradientStop Color='#CFD7E2' Offset='0.9' /> <GradientStop Color='#C4CBD8' Offset='1' /> </LinearGradientBrush.GradientStops>
            </LinearGradientBrush>        
        </ToolBarTray.Background>
            <ToolBar Background = 'Transparent' Band = '1' BandIndex = '1'>
                <Button x:Name = 'RunButton' Width = 'Auto' ToolTip = 'Performs action.'>
                    <Image x:Name = 'StartImage' Source = '$Pwd\Images\Start.jpg'/>
                </Button>         
                <Separator Background = 'Black'/>   
                <Button x:Name = 'CancelButton' Width = 'Auto' ToolTip = 'Cancels currently running operations.' IsEnabled = 'False'>
                    <Image x:Name = 'CancelImage' Source = '$pwd\Images\Stop_locked.jpg' />
                </Button>
                <Separator Background = 'Black'/>
                <ComboBox x:Name = 'RunOptionComboBox' Width = 'Auto' IsReadOnly = 'True'
                SelectedIndex = '0'>
                    <TextBlock> Connect to Office 365 </TextBlock>
                    <TextBlock> Get Office 365 Groups </TextBlock>
                    <TextBlock> Get deleted Office 365 Groups </TextBlock>
                    <TextBlock> Restore Office 365 Groups </TextBlock>
                </ComboBox>                
            </ToolBar>
            <ToolBar Background = 'Transparent' Band = '1' BandIndex = '1'>
                <Button x:Name = 'GenerateReportButton' Width = 'Auto' ToolTip = 'Generates a report based on user selection.'>
                    <Image Source = '$pwd\Images\Gen_Report.gif' />
                </Button>            
                <ComboBox x:Name = 'ReportComboBox' Width = 'Auto' IsReadOnly = 'True' SelectedIndex = '0'>
                    <TextBlock> CSV Report </TextBlock>
                    <TextBlock> HTML Report </TextBlock>
                </ComboBox>              
                <Separator Background = 'Black'/>
            </ToolBar>           
        </ToolBarTray>
        <Grid Grid.Row = '2' Grid.Column = '0' ShowGridLines = 'false'>  
            <Grid.Resources>
                <Style x:Key="AlternatingRowStyle" TargetType="{x:Type Control}" >
                    <Setter Property="Background" Value="LightGray"/>
                    <Setter Property="Foreground" Value="Black"/>
                    <Style.Triggers>
                        <Trigger Property="ItemsControl.AlternationIndex" Value="1">                            
                            <Setter Property="Background" Value="White"/>
                            <Setter Property="Foreground" Value="Black"/>                                
                        </Trigger>                            
                    </Style.Triggers>
                </Style>                    
            </Grid.Resources>                  
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height = 'Auto'/>
                <RowDefinition Height = 'Auto'/>
                <RowDefinition Height = '*'/>
                <RowDefinition Height = '*'/>
                <RowDefinition Height = 'Auto'/>
                <RowDefinition Height = 'Auto'/>
                <RowDefinition Height = 'Auto'/>
            </Grid.RowDefinitions> 
            <GroupBox Header = "Office 365 Groups List" Grid.Column = '0' Grid.Row = '2' Grid.ColumnSpan = '11' Grid.RowSpan = '3'>
                <Grid Width = 'Auto' Height = 'Auto' ShowGridLines = 'false'>
                <ListView x:Name = 'Listview' AllowDrop = 'True' AlternationCount="2" ItemContainerStyle="{StaticResource AlternatingRowStyle}"
                ToolTip = 'List that displays all information regarding groups.'>
                    <ListView.View>
                        <GridView x:Name = 'GridView' AllowsColumnReorder = 'True' ColumnHeaderTemplate="{StaticResource HeaderTemplate}">
                            <GridViewColumn x:Name = 'Name' Width = 'Auto' DisplayMemberBinding = '{Binding Path = Name}' Header='Name'/> 
							<GridViewColumn x:Name = 'Alias' Width = 'Auto' DisplayMemberBinding = '{Binding Path = Alias}' Header='Alias'/> 
							<GridViewColumn x:Name = 'Server' Width = 'Auto' DisplayMemberBinding = '{Binding Path = Server}' Header='Server'/>
							<GridViewColumn x:Name = 'AccessType' Width = 'Auto' DisplayMemberBinding = '{Binding Path = AccessType}' Header='AccessType'/>
							<GridViewColumn x:Name = 'Notes' Width = 'Auto' DisplayMemberBinding = '{Binding Path = Notes}' Header='Notes'/>
                        </GridView>
                    </ListView.View>        
                </ListView>                
                </Grid>
            </GroupBox>                                    
        </Grid>        
        <ProgressBar x:Name = 'ProgressBar' Grid.Row = '3' Height = '20' ToolTip = 'Displays progress of current action via a graphical progress bar.'/>   
        <TextBox x:Name = 'StatusTextBox' Grid.Row = '4' ToolTip = 'Displays current status of operation'> Waiting for Action... </TextBox>                           
    </Grid>   
</Window>
"@ 

#region Load XAML into PowerShell
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$uiHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
#endregion
 
#region Background runspace to clean up jobs
$jobCleanup.Flag = $True
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"          
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("uiHash",$uiHash)          
$newRunspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
$newRunspace.SessionStateProxy.SetVariable("jobs",$jobs) 
$jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    Do {    
        Foreach($runspace in $jobs) {
            If ($runspace.Runspace.isCompleted) {
                $runspace.powershell.EndInvoke($runspace.Runspace) | Out-Null
                $runspace.powershell.dispose()
                $runspace.Runspace = $null
                $runspace.powershell = $null               
            } 
        }
        #Clean out unused runspace jobs
        $temphash = $jobs.clone()
        $temphash | Where {
            $_.runspace -eq $Null
        } | ForEach {
			Write-Verbose ("Removing {0}" -f $_.DisplayName)
            $jobs.remove($_)
        }        
        Start-Sleep -Seconds 1     
    } while ($jobCleanup.Flag)
})
$jobCleanup.PowerShell.Runspace = $newRunspace
$jobCleanup.Thread = $jobCleanup.PowerShell.BeginInvoke()  
#endregion

#region Connect to all controls
$uiHash.GenerateReportMenu = $uiHash.Window.FindName("GenerateReportMenu")
$uiHash.GenerateReportButton = $uiHash.Window.FindName("GenerateReportButton")
$uiHash.ReportComboBox = $uiHash.Window.FindName("ReportComboBox")
$uiHash.StartImage = $uiHash.Window.FindName("StartImage")
$uiHash.CancelImage = $uiHash.Window.FindName("CancelImage")
$uiHash.ClearErrorMenu = $uiHash.Window.FindName("ClearErrorMenu")
$uiHash.RunOptionComboBox = $uiHash.Window.FindName("RunOptionComboBox")
$uiHash.ViewErrorMenu = $uiHash.Window.FindName("ViewErrorMenu")
$uiHash.ExitMenu = $uiHash.Window.FindName("ExitMenu")
$uiHash.RunMenu = $uiHash.Window.FindName('RunMenu')
$uiHash.AboutMenu = $uiHash.Window.FindName("AboutMenu")
$uiHash.HelpFileMenu = $uiHash.Window.FindName("HelpFileMenu")
$uiHash.Listview = $uiHash.Window.FindName("Listview")
$uiHash.StatusTextBox = $uiHash.Window.FindName("StatusTextBox")
$uiHash.ProgressBar = $uiHash.Window.FindName("ProgressBar")
$uiHash.RunButton = $uiHash.Window.FindName("RunButton")
$uiHash.CancelButton = $uiHash.Window.FindName("CancelButton")
$uiHash.GridView = $uiHash.Window.FindName("GridView")
#endregion

#region Event Handlers

#Window Load Events
$uiHash.Window.Add_SourceInitialized({  
    #Define hashtable of settings
    $Script:SortHash = @{}
    
    #Sort event handler
    [System.Windows.RoutedEventHandler]$Global:ColumnSortHandler = {
        If ($_.OriginalSource -is [System.Windows.Controls.GridViewColumnHeader]) {
            Write-Verbose ("{0}" -f $_.Originalsource.getType().FullName)
            If ($_.OriginalSource -AND $_.OriginalSource.Role -ne 'Padding') {
                $Column = $_.Originalsource.Column.DisplayMemberBinding.Path.Path
                Write-Debug ("Sort: {0}" -f $Column)
                If ($SortHash[$Column] -eq 'Ascending') {
                    Write-Debug "Descending"
                    $SortHash[$Column]  = 'Descending'
                } Else {
                    Write-Debug "Ascending"
                    $SortHash[$Column]  = 'Ascending'
                }
                Write-Verbose ("Direction: {0}" -f $SortHash[$Column])
                $lastColumnsort = $Column
                Write-Verbose "Clearing sort descriptions"
                $uiHash.Listview.Items.SortDescriptions.clear()
                Write-Verbose ("Sorting {0} by {1}" -f $Column, $SortHash[$Column])
                $uiHash.Listview.Items.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription $Column, $SortHash[$Column]))
                Write-Verbose "Refreshing View"
                $uiHash.Listview.Items.Refresh()   
            }             
        }
    }
    $uiHash.Listview.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, $ColumnSortHandler)
    
    #Create and bind the observable collection to the GridView
    $Script:clientObservable = New-Object System.Collections.ObjectModel.ObservableCollection[object]    
    $uiHash.ListView.ItemsSource = $clientObservable
    $Global:Clients = $clientObservable | Select -Expand Computer
})    

#Window Close Events
$uiHash.Window.Add_Closed({
    #Halt job processing
    $jobCleanup.Flag = $False

    #Stop all runspaces
    $jobCleanup.PowerShell.Dispose()
    
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()    
})

#Cancel Button Event
$uiHash.CancelButton.Add_Click({
    $runspaceHash.runspacepool.Dispose()
    $uiHash.StatusTextBox.Foreground = "Black"
    $uiHash.StatusTextBox.Text = "Action cancelled" 
    [Float]$uiHash.ProgressBar.Value = 0
    $uiHash.RunButton.IsEnabled = $True
    $uiHash.StartImage.Source = "$pwd\Images\Start.jpg"
    $uiHash.CancelButton.IsEnabled = $False
    $uiHash.CancelImage.Source = "$pwd\Images\Stop_locked.jpg"    
         
}) 

#View Error Event
$uiHash.ViewErrorMenu.Add_Click({
    Get-Error | Out-GridView
})

#Report Generation
$uiHash.GenerateReportButton.Add_Click({
    Start-Report
})

#Exit Menu
$uiHash.ExitMenu.Add_Click({
	if((get-pssession).count -gt 0){
		get-pssession | remove-pssession
	}
    $uiHash.Window.Close()
})

#Run Menu
$uiHash.RunMenu.Add_Click({
    $credential = Start-RunJob -credential $credential
}) 

#AboutMenu Event
$uiHash.AboutMenu.Add_Click({
    Open-About
})

#HelpFileMenu Event
$uiHash.HelpFileMenu.Add_Click({
    Open-Help
})

#Clear Error log
$uiHash.ClearErrorMenu.Add_Click({
    Write-Verbose "Clearing error log"
    $Error.Clear()
})

#RunButton Events    
$uiHash.RunButton.add_Click({
    Start-RunJob      
})

#Key Up Event
$uiHash.Window.Add_KeyUp({
    $Global:Test = $_
    Write-Debug ("Key Pressed: {0}" -f $_.Key)
    Switch ($_.Key) {
        "F1" {Open-Help}
        "F5" {Start-RunJob}
        "F8" {Start-Report}
        Default {$Null}
    }

})

#endregion        

#Start the GUI
$uiHash.Window.ShowDialog() | Out-Null

#close session
if((get-pssession).count -gt 0){
		get-pssession | remove-pssession
}