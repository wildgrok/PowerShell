# HelloWorld_InlineScript_parameters2.ps1
workflow HelloWorld 
{    
    # This will used as parameter in below inlinescript
    $p1 = "a|b|c|d|e"
    $p1   
    "--------------------------------------------------------"
    " The value of the parameter is displayed ok"
    InlineScript # Showing use of parameter
    {
        # using an external value as parameter
        $using:p1
        # doing something with it
        $r1 = ($using:p1).Split('|')
        # just displaying
        $r1
    }

    "--------------------------------------------------------"
    $retval = InlineScript # Showing how to return something from the inlinescript
    {     
        $s1 = "some internal value generated within"       
        return $s1
    } 
    " A return value:"
    " Expected : some internal value generated within"
    $retval
    " It worked as expected"   
    "--------------------------------------------------------"
    $retval = InlineScript # SHOWING THE UNEXPECTED
    {  
        "this is something unexpected before  "     
        $s1 = "some internal value generated within"    
        "this is something unexpected after  "     
        return $s1
    } 
    " A return value:"
    " Expected : some internal value generated within"
    " And we got the expected value preceded by both display values!"
    $retval
    "--------------------------------------------------------"      
}
HelloWorld  # and we execute the workflow

