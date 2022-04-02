{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) FIELDS([]) PROPERTIES([])}

{$IFDEF ConditionalExpressions}
  {$IF CompilerVersion >= 21.0} { Borland Delphi 2010 }
    {$DEFINE DELPHI2010}
  {$IFEND}
{$ENDIF}
