<html t:params=$app>
<t:include path=_macro.html.tm />
<title>Documentation - TR</title>
<link rel=stylesheet href=/css/common.css>
<body>

<t:include path=_header.html.tm />

<section>
  <h1>Basic concepts and operations</h1>

  <section id=repos>
    <h1>Repositories</h1>

    <p>本サイトで編集できるのは Git で管理されたリポジトリーです。
    GitHub などにある大元のリポジトリーを<dfn>遠隔リポジトリー</dfn>、
    本サイト上で編集するリポジトリーを<dfn>テキストリポジトリー</dfn>と呼びます。
    <p>本サイトは遠隔リポジトリーを pull して表示し、
    編集があると遠隔リポジトリーへと push します。
  </section>

  <section id=acl>
    <h1>編集権限</h1>

    <p>リポジトリーの所有者は、すべての操作が可能です。
    <p>リポジトリーへの変更は、所有者のアカウントを使って遠隔リポジトリーに
    push されます。所有者は遠隔リポジトリーの push 
    権限を持っている必要があります。
    <p>所有者は1人だけです。遠隔リポジトリーの push 権限を持っている人は、
    リポジトリーの編集権限設定から所有権を取得できます。

    <hr>

    <p>所有者は、リポジトリーの編集権限設定から他の利用者に編集やコメントの権限を与えることができます。
    遠隔リポジトリーの push 権限を持っている人は、リポジトリーに参加することで所有者の操作なく編集権限を得ることができます。
    (遠隔リポジトリーの pull/push 権限を持たない人にも表示、編集の権限を与えることができます。)
    <p>なお、遠隔リポジトリーが公開されている場合は、
    テキストリポジトリーは誰でも表示できる状態になります。
    遠隔リポジトリーを公開から非公開に変更した場合は、
    リポジトリーの編集権限設定から所有権を再取得することで、
    テキストリポジトリーを非公開にできます。
  </section>

</section>

<t:include path=_footer.html.tm m:app=$app />
