<html t:params=$app>
<t:include path=_macro.html.tm />
<title>サイト管理権限 - TR</title>
<link rel=stylesheet href=/css/common.css>
<body>

<t:include path=_header.html.tm />

<section>
  <h1>サイト管理権限</h1>

  <p><a href="/r/about:siteadmin/acl">サイト管理権限の管理</a>

  <form action=/admin/account method=post>
    <button type=submit>サイト管理権限を取得</button>
  </form>
</section>

<t:include path=_footer.html.tm m:app=$app />
