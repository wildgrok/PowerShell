workflow HelloWorld
{    
    "This will used as parameter in below inlinescript"
    $p1 = "a|b|c|d|e"
    $p1
    # This DOES NOT WORK - InlineScript is not a Script Block:
    # InlineScript ($p1) orInlineScript { param ($p1) ... }
    "--------------------------------------------------------"
    InlineScript #Showing use of a parameter (AKA external value)
    {
        # DON'T DO THIS (in case you did not read above note): param($using:p1)
        "received a parameter"
        $using:p1
        "doing something to it"
        $r1 = ($using:p1).Split('|')        
        $r1
    } 
    "--------------------------------------------------------"
    $retval = InlineScript #Showing how to return something from the inlinescript
    {       
        $s1 = "some internal value generated within"       
        return $s1
    } 
    " A return value:"
    $retval
    "--------------------------------------------------------"    
    $retval2 = InlineScript #Combining both: use parameter, return value
    {
        "received a parameter"
        $using:p1
        "doing something to it"
        $r1 = ($using:p1).Split('|')       
        return $r1
    } 
    "Return value:"
    $retval2
    InlineScript
    {
        "Just printing the date and time here again"
        Get-Date       
    }
}
HelloWorld  # and we execute the workflow