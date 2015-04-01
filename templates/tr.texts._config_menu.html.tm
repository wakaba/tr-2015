<html t:params=$selected>
<body>
  <nav>
    <p>
      <t:class name="$selected eq 'langs' ? 'selected' : undef">
      <a href=langs>言語</a>
    <p>
      <t:class name="$selected eq 'license' ? 'selected' : undef">
      <a href=license>ライセンス</a>

    <hr>
    <p><a href=../../acl>アクセス制御</a>

  </nav>
