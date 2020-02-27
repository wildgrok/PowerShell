workflow HelloWorld
{    
    "This will used as parameter in below inlinescript"
    $p1 = "a|b|c|d|e"
    $p1
    "--------------------------------------------------------"
    InlineScript # Showing use of a parameter (AKA external value)
    {
       # received a parameter
        $using:p1
       # doing something with it"
        $r1 = ($using:p1).Split('|')  
        #  Just displaying
        $r1
    } 
    "--------------------------------------------------------"
    $retval = InlineScript #Showing how to return something from the inlinescript
    {       
        $s1 = "some internal value generated within"       
        return $s1
    } 
    " A return value:"
    $retval
    "--------------------------------------------------------"    
    $retval2 = InlineScript # Combining both: use parameter, return value
    {
        # Using a parameter
        $using:p1
        # Doing something with it
        $r1 = ($using:p1).Split('|')       
        return $r1
    } 
    "Return value:"
    $retval2
}

HelloWorld  # and we execute the workflow
