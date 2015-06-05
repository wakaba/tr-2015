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

  <section id=textset>
    <h1>テキスト集合</h1>

    <p>テキスト集合ディレクトリーの名前に使えるのは、 ASCII
    英数字と <code>-</code>, <code>_</code>, <code>.</code> のみです。
    ディレクトリーの最初の文字は ASCII 英数字か <code>_</code>
    でなければなりません。テキスト集合ディレクトリーの階層は
    <code>/</code> で区切って <code>/foo/bar</code> のように表します。
    リポジトリーの最上位階層は <code>/</code> と表します。
    最初の <code>/</code> も含めて全体で64文字以内でなければなりません。
    <p>テキスト集合を構成するファイル群は、テキスト集合ディレクトリー内の
    <code>texts</code> ディレクトリー以下に保存されます。

    <p>A text set directory can have a JSON file named
    as <dfn id=config.json><code>config.json</code></dfn>, which is
    used to store various configuration options applied to the text
    set.  The file contains a UTF-8 encoded JSON object with following
    names:

      <ul>
      <li><a href=#config-location_base_url><code>location_base_url</code></a>
      </ul>
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

  <section id=texts>
    <h1>テキスト</h1>

    <p>テキスト集合に含まれる一単位の文章片を<dfn id=text>テキスト</dfn>と呼びます。
    <p>テキストには<dfn id=text-id>テキストID</dfn>が割り振られています。
    テキストIDは3文字以上128文字以下の ASCII 数字と
    <code>a</code>-</code>f</code> の16種類の文字で構成される記号列です。
    テキストIDは、同じテキスト集合の他のどのテキストのテキストIDとも異なる値でなければなりません。

    <p>テキストIDはテキスト集合内部の管理のためのIDです。
    テキストを使うプログラム等から参照する際はテキストIDではなくメッセージIDを使うことができます。
  </section>

  <section id=add>
    <h1>テキストの追加</h1>

    <p>テキストは、編集ページ下部の「テキスト追加」フォームから追加できます。
    (「テキストの管理」権限が必要です。)

    <p>テキストは <code>.po</code> ファイルなどをインポートすることでも追加できます。
    インポートページは、編集ページ右上のアイコンから開くことができます。
    一度にたくさんのテキストを追加したい場合はこちらを使うと便利です。
  </section>

  <section id=langs>
    <h1>言語</h1>

    <p><dfn id=lang-key>言語キー</dfn>はテキスト集合内で言語を表す短い記号列です。
    64文字以内の ASCII 小文字・数字・<code>-</code> 
    で構成される文字列でなければなりません。ただし先頭は小文字か数字でなければなりません。

    <p>言語キーはテキスト集合を使うプログラムなどが使っている言語名に合わせると便利です。
    例えば日本語は <code>ja</code>、イギリス英語は <code>en-gb</code>
    などとするのが良いと考えられます。

    <p>言語キーは IETF の言語タグでなくても構いませんが、
    言語タグに揃えた方が便利かもしれません。
  </section>
</section>

<section>
  <h1>ファイル出力</h1>

  <section>
    <h1>制約</h1>

    <p>リポジトリー内のファイル名は、ディレクトリー名や区切りの
    <code>/</code> も含めて50文字以下でなければなりません。
    ファイル名に使えるのは ASCII 英数字、 <code>_</code>、
    <code>.</code>、<code>@</code>、<code>+</code>、<code>-</code>
    のみです。ディレクトリー名とファイル名の先頭文字は英数字か
    <code>_</code> でなければなりません。
  </section>
</section>

<section>
  <h1>Text source annotations</h1>

  <p>The <dfn id=config-location_base_url><code>location_base_url</code></dfn>
  <a href=#config.json>text set configuration option</a> specifies the
  base URL used to resolve URLs specified for source locations.  It
  must be an absolute URL whose scheme is <code>http</code>
  or <code>https</code>.
</section>

<section>
  <h1>サイト管理</h1>

  <section>
    <h1>サイト管理リポジトリー</h1>

    <p>サイトごとに1つ、特別なリポジトリー (URL <code>about:siteadmin</code>)
    があります。このリポジトリーにはサイト全体の設定が格納されています。
    <p>このリポジトリーの編集権限は、他のリポジトリーと同じように編集できます。
    また、利用者名 <code>admin</code> と初期設定時に発行されたパスワードを使って<a href=/admin/account>管理権限を取得</a>できます。
  </section>

  <section>
    <h1>リポジトリー規則</h1>

    <p>サイト管理者は<a href=/admin/repository-rules>リポジトリー規則の編集</a>を行えます。
    リポジトリー規則に合致する Git リポジトリーをそのサイトで編集できるようになります。

    <dl>

    <dt><code>file-public</code>
    <dd>Git repositories in a local file system.  Administrators of
    the site can join the repository as owners.  Repositories are
    marked as <i>public</i> such that anyone can read the repository.

    <dt><code>file-private</code>
    <dd>Git repositories in a local file system.  Administrators of
    the site can join the repository as owners.  Repositories are
    marked as <i>private</i> such that only members of the repository
    can read the repository.

    </dl>
  </section>
</section>

<t:include path=_footer.html.tm m:app=$app />
