<html t:params="$tr $tr_config $app" class=config-page>
<t:my as=$start x="$app->bare_param ('start')">
<title>Languages - Text set configuration - XXX</title>
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
      <p class=selected><a href>言語設定</a>
      <p>ライセンス設定
      <p>初期設定完了
    </nav>
  <t:else>
    <t:include path=tr.texts._config_menu.html.tm m:selected="'langs'" />
  </t:if>

  <section class=config>
    <header>
      <h1>言語設定</h1>
    </header>

    <form action=langs.ndjson method=post>
      <t:if x=$start>
        <t:attr name="'data-next'" value="'license?start=1'">
      </t:if>

      <table class=langs>
        <thead>
          <tr>
            <th colspan=2>識別子
            <th>言語名
            <th>
        </thead>
        <tbody>
          <template class=lang-template>
            <th>
              <input type=hidden name=lang_key value>
              <code class=lang-key>{lang_key}</code>
            <td>
              <input type=hidden name=lang_id value>
              <code class=lang-id>{lang_id}</code>
            <td>
              <input type=hidden name=lang_label value>
              <span class=lang-label>{lang_label}</span>
              <input type=hidden name=lang_label_short value>
              <span class=lang-label-short>{lang_label_short}</span>
            <td>
              <button type=button onclick="
                if (!confirm (getAttribute ('data-confirm'))) return;
                parentNode.parentNode.parentNode.removeChild (parentNode.parentNode);
                document.trModified = true;
              " data-confirm=この言語を削除します>削除</button>
          </template>
      </table>

      <div>
        <select>
          <option value>(Choose a language)
          <option value=ja>Japanese
          <option value=en>English
          <option value=fr>French
          <option value=ja-latn>Japanese (Latin)
          <option value=i-default>i-default
        </select>
        <button type=button onclick="
          var langKey = parentNode.querySelector ('select').value;
          if (langKey) {
            var langRow = document.querySelector ('table.langs tr[data-lang=&#x22;'+langKey+'&#x22;]'); // XXX CSS escape
            if (langRow) return;
            addLang ({key: langKey, id: langKey,
                      label: langKey, label_short: langKey,
                      label_raw: '', label_short_raw:''});
            document.trModified = true;
          }
        ">Add</button>
      </div>

      <p class=buttons><button type=submit class=save>保存する</button>
    </form>
    <p class=status hidden><progress></progress> <span class=message></span>

    <script src=/js/core.js charset=utf-8 />
    <script>
      function addLang (lang) {
        var table = document.querySelector ('table.langs');
        var trTemplate = table.querySelector ('.lang-template');
        var tr = document.createElement ('tr');
        tr.setAttribute ('data-lang', lang.key);
        tr.innerHTML = trTemplate.innerHTML;
        tr.querySelector ('.lang-key').textContent = lang.key;
        tr.querySelector ('input[name=lang_key]').value = lang.key;
        tr.querySelector ('.lang-id').textContent = lang.id;
        tr.querySelector ('.lang-id').hidden = lang.key === lang.id;
        tr.querySelector ('input[name=lang_id]').value = lang.id;
        tr.querySelector ('.lang-label').textContent = lang.label;
        tr.querySelector ('input[name=lang_label]').value = lang.label_raw;
        tr.querySelector ('.lang-label-short').textContent = lang.label_short;
        tr.querySelector ('.lang-label-short').hidden = lang.label === lang.label_short;
        tr.querySelector ('input[name=lang_label_short]').value = lang.label_short_raw;
        table.tBodies[0].appendChild (tr);
      } // addLang

      (function () {
        var status = document.querySelector ('.config .status');
        showProgress ({init: true, message: 'Loading...'}, status);
        server ('GET', 'info.ndjson', null, function (res) {
          res.data.avail_lang_keys.forEach (function (langKey) {
            addLang (res.data.langs[langKey]);
          });
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
