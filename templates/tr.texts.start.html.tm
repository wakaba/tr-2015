<html t:params="$tr $app" class=config-page>
<title>初期設定 - Text set configuration - XXX</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" if (document.trModified) return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a href="../../" rel="up up up"><code itemprop=url><t:text value="$tr->url"></code></a></h1>
      <h2 title=Branch><a href="../" rel="up up"><code itemprop=branch><t:text value="$tr->branch"></code></a></h2>
      <h3 title=Path><a href="./" rel=up><code itemprop=texts-path><t:text value="'/' . $tr->texts_dir"></code></a></h3>
    </hgroup>
  </header>

  <nav>
    <p class=done>ログイン
    <p class=done><a href=/tr>リポジトリー選択</a>
    <p class=done><a href=../../start>編集対象選択</a>
    <p class=selected><a href>既存データインポート</a>
    <p>言語・ライセンス設定
    <p>初期設定完了
  </nav>

  <section class=config>
    <header>
      <h1>初期設定</h1>
    </header>
    <p class=status hidden><progress></progress> <span class=message></span>

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

<t:include path=_footer.html.tm m:app=$app />
