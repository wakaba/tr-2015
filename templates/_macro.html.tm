<t:macro name=timestamp t:params=$value>
  <time pl:datetime="
    my @time = gmtime $value;
    sprintf '%04d-%02d-%02dT%02d:%02d:%02dZ',
        $time[5] + 1900, $time[4] + 1, $time[3],
        $time[2], $time[1], $time[0];
  "><t:text value="
    my @time = gmtime $value;
    sprintf '%d/%d/%d %d:%02d UTC',
        $time[5] + 1900, $time[4] + 1, $time[3],
        $time[2], $time[1];
  "></time>
</t:macro>
