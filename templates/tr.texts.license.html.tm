<html t:params="$tr $tr_config $app" class=config-page>
<t:my as=$start x="$app->bare_param ('start')">
<title>License - Text set configuration - XXX</title>
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

  <t:if x=$start>
    <nav>
      <p class=done>ログイン
      <p class=done><a href=/tr>リポジトリー選択</a>
      <p class=done><a href=../../start>編集対象選択</a>
      <p class=done><a href=start>インポート</a>
      <p class=done><a href=langs>言語設定</a>
      <p class=selected><a href>ライセンス設定</a>
      <p>初期設定完了
    </nav>
  <t:else>
    <t:include path=tr.texts._config_menu.html.tm m:selected="'license'" />
  </t:if>

  <section class=config>
    <header>
      <h1>ライセンス設定</h1>
    </header>

    <form action="license.ndjson" method=post>
      <t:if x=$start>
        <t:attr name="'data-next'" value="'./'">
      </t:if>

      <table class=config>
        <tbody>
          <tr>
            <th><label for=config-license-type>ライセンス
            <td>
              <select name=type id=config-license-type required>
                <option value>ライセンスを選択
                <option value=CC0>CC0
                <option value=Public-Domain>Public Domain
                <option value=MIT>MIT ライセンス
                <option value=BSDModified>修正 BSD ライセンス
                <option value=Apache2>Apache License 2.0
                <option value=GPL2+>GPL2 以降
                <option value=GPL3+>GPL3 以降
                <option value=CC-BY-SA4>CC BY-SA 4.0
                <option value=Perl>Perl と同じ
                <option value=proprietary>独占的ライセンス
              </select>
          <tr>
            <th><label for=config-license-holders>ライセンス保有者</label>
            <td><input name=holders id=config-license-holders>
          <tr>
            <th><label for=config-license-additional_terms>追加のライセンス条項</label>
            <td><textarea name=additional_terms id=config-license-additional_terms></textarea>
      </table>

      <p class=buttons><button type=submit class=save>保存する</button>
    </form>
    <p class=status hidden><progress></progress> <span class=message></span>

    <script src=/js/core.js charset=utf-8 />
    <script>
      (function () {
        var form = document.querySelector ('.config form');
        var status = document.querySelector ('.config .status');
        showProgress ({init: true, message: 'Loading...'}, status);
        server ('GET', 'info.ndjson', null, function (res) {
          form.elements.type.value = res.data.license.type;
          form.elements.holders.value = res.data.license.holders || '';
          form.elements.additional_terms.value = res.data.license.additional_terms || '';
          status.hidden = true;
        }, function (json) {
          showError (json, status);
        }, function (json) {
          showProgress (json, status);
        });
      }) ();

      var form = document.querySelector ('.config form');
      form.onchange = function () { document.trModified = true };
      form.onsubmit = function (ev) {
        var form = ev.target;
        var status = document.querySelector ('.config .status');
        showProgress ({init: true}, status);
        server ('POST', form.action, new FormData (form), function (res) {
          showDone (res, status);
          document.trModified = false;
          if (form.getAttribute ('data-next')) {
            location.href = form.getAttribute ('data-next');
          }
        }, function (json) {
          showError (json, status);
        }, function (json) {
          showProgress (json, status);
        });
        return false;
      };
    </script>
  </section>
</section>

<t:include path=_footer.html.tm m:app=$app />
