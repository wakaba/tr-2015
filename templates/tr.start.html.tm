<html t:params="$tr $app" class=config-page>
<title>初期設定 - Repository configuration - XXX</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" if (document.trModified) return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a href="./" rel="up"><code itemprop=url><t:text value="$tr->url"></code></a></h1>
    </hgroup>
  </header>

  <nav>
    <p class=done>ログイン
    <p class=done><a href=/tr>リポジトリー選択</a>
    <p class=selected><a href>ブランチ・テキスト集合選択</a>
    <p>既存データインポート
    <p>言語・ライセンス設定
    <p>初期設定完了
  </nav>

  <section class=config>
    <header>
      <h1>初期設定</h1>
    </header>
    <p class=status hidden><progress></progress> <span class=message></span>

    <table class=config>
      <tbody>
        <tr>
          <th>ブランチ
          <td>
        <tr>
          <th>テキスト集合
          <td>
    </table>

    <p>既存データのインポート

    <table class=config>
      <tbody>
        <tr>
          <th>言語
          <td>
        <tr>
          <th>ライセンス
          <td>
    </table>

    <p><a href=./>完了</a>

  </section>
</section>

<t:include path=_footer.html.tm />
