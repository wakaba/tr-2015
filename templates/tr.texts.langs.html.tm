<html t:params="$tr $tr_config $app">
<title>XXX</title>
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

  <section class=config-langs>
    <header>
      <h1>言語設定</h1>
    </header>

    <form action=langs method=post>
      <table class=langs>
        <thead>
          <tr>
            <th colspan=2>識別子
            <th>言語名
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

      <p class=buttons><button type=submit class=save-button data-save-and-close="保存して閉じる">保存</button>
      <p class=status hidden><progress></progress> <span class=message></span>
    </form>

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

      // XXX progress
      var xhr = new XMLHttpRequest;
      xhr.open ('GET', 'langs.json', true);
      xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
          if (xhr.status === 200) {
            var json = JSON.parse (xhr.responseText);
            json.avail_lang_keys.forEach (function (langKey) {
              addLang (json.langs[langKey]);
            });
          } else {
            // XXX
          }
        }
      };
      xhr.send (null);

      document.querySelector ('.config-langs form').onsubmit = function () {
        // XXX progress
        var form = this;
        var xhr = new XMLHttpRequest;
        xhr.open ('POST', form.action, true);
        xhr.onreadystatechange = function () {
          if (xhr.readyState === 4) {
            if (xhr.status === 200) {
              var json = JSON.parse (xhr.responseText);
              document.trModified = false;
              if (window.opener) window.close ();
            } else {
              // XXX
            }
          }
        };
        var fd = new FormData (form);
        xhr.send (fd);
        return false;
      };
      if (window.opener) {
        var button = document.querySelector ('.save-button');
        button.textContent = button.getAttribute ('data-save-and-close');
      }
    </script>
  </section>
</section>

<t:include path=_footer.html.tm />
