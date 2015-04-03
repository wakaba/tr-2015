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
    <p class=selected><a href>インポート</a>
    <p>言語設定
    <p>ライセンス設定
    <p>初期設定完了
  </nav>

  <section class=config>
    <header>
      <h1>初期設定</h1>
    </header>
    <p class=status hidden><progress></progress> <span class=message></span>

    <p>リポジトリーに既に言語データファイル (<code>.po</code> ファイル)
    が含まれている場合は、初期データとしてインポートできます。

    <form action=import.ndjson method=post enctype=multipart/form-data>
      <input type=hidden name=from value=repo>

      <table class=config>
        <tr>
          <th><label for=import-arg_format>Argument format</label>
          <td>
            <select id=import-arg_format name=arg_format>
              <option value=auto>Auto
              <option value=printf>printf
              <option value=percentn>%n
              <option value=braced>{placeholder}
            </select>
      </table>

      <button type=submit>既存データをインポート</button>
    </form>

    <p class=info>リポジトリー内にないファイルからは、
      初期設定完了後にインポート機能でインポートできます。

    <p class=buttons><button type=button onclick="
      location.href = 'langs?start=1';
    ">次へ進む</button>

    <script src=/js/core.js charset=utf-8 />
    <script>
      Array.prototype.forEach.call (document.querySelector ('section.config').querySelectorAll ('form[method=post]'), function (form) {
        form.onsubmit = function () {
          var status = document.querySelector ('.status');
          showProgress ({init: true}, status);
          server ('POST', form.action, new FormData (form), function (res) {
            showDone (res, status);
          }, function (json) {
            showError (json, status);
          }, function (json) {
            showProgress (json, status);
          });
          return false;
        };
      });
    </script>
  </section>
</section>

<t:include path=_footer.html.tm m:app=$app />
