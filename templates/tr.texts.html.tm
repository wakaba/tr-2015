<html t:params="$tr $app $query">
<t:call x="use Wanage::URL">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" if (isEditMode ()) return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<t:include path=_header.html.tm />

<section>

<header class=textset itemscope itemtype=data>
  <hgroup> 
    <h1 title=Repository><a href="../../" rel="up up"><code itemprop=url><t:text value="$tr->url"></code></a></h1>
    <h2 title=Branch><a href="../" rel=up><code itemprop=branch><t:text value="$tr->branch"></code></a></h2>
    <h3 title=Path><a href="./" rel=bookmark><code itemprop=texts-path><t:text value="'/' . $tr->texts_dir"></code></a></h3>
  </hgroup>
  <!-- XXX public/private -->
  <!-- XXX link to LICENSE -->
  <link itemprop=data-url pl:href="'data.ndjson?with_comments=1'">
  <link itemprop=export-url pl:href="'export?'">
  <meta itemprop=lang-params pl:content="join '&', map { 'lang=' . percent_encode_c $_ } @{$app->text_param_list ('lang')}">

  <nav class=toolbar>
    <a href="#share" onclick=" modalDialog ('share', true); return false " class=share title="共有">Share</a>
    <a href=import class=import title="テキスト集合に外部データを取り込み" target=config>Import</a><!-- XXX lang= & tag=  -->
    <a href="#export" onclick=" modalDialog ('export', true); return false " class=export title="テキスト集合からデータファイルを生成">Export</a>
    <button type=button class=settings title="設定を変更" onclick="
      var menu = this.nextElementSibling;
      menu.hidden = !menu.hidden;
    ">設定</button>
    <menu hidden class=contextmenu onclick="
      if (event.target.localName === 'a') {
        event.currentTarget.hidden = true;
      }
    ">
      <p><a href="#config-langs" onclick=" modalDialog ('config-langs', true); return false ">表示言語...</a>
      <p><a href=license target=config>ライセンス...</a>
      <hr>
      <p><a href=../../acl target=config>編集権限...</a>
    </menu>
  </nav>

  <form action="./" method=get class=filter>
    <p>
      <input type=search name=q pl:value="$query->stringify" placeholder="Filtering by words">
      <button type=submit>Apply</button>
      <a href="XXX" rel=help title="Filter syntax" target=help>Advanced</a>
    <!-- XXX langs -->
  </form>
</header>

<div class="banner if-readonly" hidden>
  <p>このリポジトリーは<strong>読み取り専用</strong>です。

  <ul class=switch>
    <li>あなたがこのリポジトリーの管理者なら、<a href=../../acl target=config>編集権限設定</a>を行ってください。

      <div class=XXX>
          <p>参加すると、このリポジトリーを編集できるようになります。
          <form action=../../acl.json method=post><!-- XXX path -->
            <input type=hidden name=operation value=join>
            <button type=submit>開発者として参加</button>
          </form><!-- XXX ajax -->

        <p>SSH でアクセスするためには、公開鍵をサーバーに登録してください。
          <form>
            <input name=public_key>
            <button type=button name=show_public_key onclick="
              var form = this.form;
              var xhr = new XMLHttpRequest;
              xhr.open ('GET', '/account/sshkey.json', true);
              xhr.onreadystatechange = function () {
                if (xhr.readyState === 4) {
                  if (xhr.status === 200) {
                    var json = JSON.parse (xhr.responseText);
                    form.elements.public_key.value = json.public_key || '(未生成)';
                  } else {
                    // XXX
                  }
                }
              };
              xhr.send (null);
            ">公開鍵を表示</button>
            <button type=button onclick="
              if (!confirm (getAttribute ('data-confirm'))) return;
              var form = this.form;
              var xhr = new XMLHttpRequest;
              xhr.open ('POST', '/account/sshkey.json', true);
              xhr.onreadystatechange = function () {
                if (xhr.readyState === 4) {
                  if (xhr.status === 200) {
                    form.elements.show_public_key.click ();
                  } else {
                    // XXX
                  }
                }
              };
              xhr.send (null);
            " data-confirm="鍵を再生成すると、以前の鍵は破棄されます。">鍵を(再)生成</button>
          </form>
      </div>
    <li>あなたが管理者以外なら、<a href=XXX>管理者に編集権限を申請</a>してください。
    <li class=guest-only>既に編集権限を持っている場合は、
    <a href=XXX>ログイン</a>してください。
  </ul>
</div>

<table id=texts>
  <thead>
    <tr>
      <template class=lang-header-template>
        <span class=lang-label>{lang_label}</span>
        <hr class=resizer data-th-style="width: %%WIDTH%%" data-td-selector="#texts tbody td.lang-area[data-lang='{lang_key}']">
        <script type=text/plain class=resize-css>
          %%SELECTOR%% > .view p {
            width: %%WIDTH%%;
          }
          %%SELECTOR%% .edit textarea {
            width: %%WIDTH%%;
          }
        </script>
      </template>
      <th class=comment-header>コメント
        <hr class=resizer data-th-style="width: %%WIDTH%%" data-td-selector="#texts tbody td.comments-area">
        <script type=text/plain class=resize-css>
          %%SELECTOR%% article {
            max-width: %%WIDTH%%;
          }
          %%SELECTOR%% .edit textarea {
            width: %%WIDTH%%;
          }
        </script>
  </thead>
  <template class=text-row-template>
    <tr class=text-header>
      <th data-colspan-delta=1>
        <a class=msgid onclick=" modalDialog ('copy-id', true, {area: this.parentNode}); return false "><code></code></a>
        <a class=text_id onclick=" modalDialog ('copy-id', true, {area: this.parentNode}); return false "><code></code></a>
        <span class=tags-area>
          <strong>タグ</strong>
          <span class=tags></span>
          <template>
            <a href=... class=tag onclick=" return openQueryAnchor (this) ">...</a>
          </template>
        </span>

        <span class=args-area>
          <strong>引数</strong>
          <span class=args></span>
          <template>
            <span class=arg>
              <code>{<span class=arg_name></span>}</code>
              <span class=arg_desc></span>
            </span>
          </template>
        </span>

        <span class=desc></span>
        <span class=buttons><button type=button class=edit title="テキスト情報を編集" onclick=" modalDialog ('config-text', true, {area: parentNode.parentNode}) ">編集</button></span>
    <tr class=text-body>
      <script class=lang-area-placeholder />

      <td class=comments-area>
        <div class=comments-container></div>
        <template>
          <article>
            <p class=author_name>{author_name}
            <p class=body>{body}
            <footer><p><time>2000-01-01 00:00:00</time></footer>
          </article>
        </template>
        <form data-action="i/{text_id}/comments.ndjson" method=post class=new-comment>
          <p><textarea name=body required placeholder=補足説明、質問など></textarea>
          <p class=buttons><button type=submit>投稿</button>
        </form>
        <p class=status hidden><progress></progress> <span class=message></span>
  </template> 
  <template class=lang-area-template>
    <!-- data-lang={lang} class=lang-area -->
    <div class=view>
            <p class=body_0 data-form=0>
            <p class=body_1 data-form=1>
            <p class=body_2 data-form=2>
            <p class=body_3 data-form=3>
            <p class=body_4 data-form=4>
            <menu class=text-form-tabs>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=0>0</span>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=1>1</span>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=2>2</span>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=3>3</span>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=4>4</span>
            </menu>
    </div>
    <form data-action="i/{text_id}/text.ndjson" method=post class=edit>
      <input type=hidden name=lang value={lang_key} class=lang-key>
            <p data-form=0><textarea name=body_0></textarea>
            <p data-form=1><textarea name=body_1></textarea>
            <p data-form=2><textarea name=body_2></textarea>
            <p data-form=3><textarea name=body_3></textarea>
            <p data-form=4><textarea name=body_4></textarea>
            <p>
              <select name=forms>
                <option value=o data-fields=0>Only the default form
                <option value=1o data-fields=0,1>Singular (1) and plural
                <option value=0o data-fields=0,1>Singular (0, 1) and plural
                <option value=test data-fields=0,2,3,4>Test
              </select>
            <p class=buttons><button type=submit>保存</button>
            <menu class=text-form-tabs>
              <a href=javascript: onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=0>0</a>
              <a href=javascript: onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=1>1</a>
              <a href=javascript: onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=2>2</a>
              <a href=javascript: onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=3>3</a>
              <a href=javascript: onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=4>4</a>
            </menu>
    </form>
    <p class=status hidden>
      <span class=message></span>
      <progress></progress>
  </template>
  <tbody>
  <tbody class=status hidden>
    <tr>
      <td data-colspan-delta=1>
        <progress></progress> <span class=message></span>
</table>
<menu class=texts-lang-area-menu hidden>
  <strong class=lang-label>{lang_label}</strong>
  <button type=button class=toggle-edit>Edit</button>
  <button type=button class=search>Search</button>
  <a href data-href="i/{text_id}/history.json?lang={lang_key}" target=history>History</a>
</menu>
<menu class=texts-comments-area-menu hidden>
</menu>

<details id=add>
  <summary>テキストの追加</summary>

  <form action=add.ndjson method=post onsubmit="
    var form = this;
    var status = document.querySelector ('#texts tbody.status');
    var saveButton = form.querySelector ('button[type=submit]');
    saveButton.disabled = true;
    showProgress ({init: true}, status);
    server ('POST', form.action, new FormData (form), function (res) {
      addTexts (res.data.texts);
      saveButton.disabled = false;
      status.hidden = true;
      form.reset ();
    }, function (json) {
      showError (json, status);
      saveButton.disabled = false;
    }, function (json) {
      showProgress (json, status);
    });
    return false;
  ">
    <table class=config>
      <tbody>
        <tr>
          <th><label for=add-msgid>メッセージID</label>
          <td><input type=text name=msgid pl:value="$app->text_param ('msgid') // ''" id=add-msgid><!-- XXX duplicate check -->
        <tr>
          <th><label for=add-desc>簡単な説明</label>
          <td><input type=text name=desc id=add-desc>
        <tr class=tags-area hidden>
          <th>タグ
          <td>
            <span class=tags></span>
            <template>
              <a href=... class=tag onclick=" return openQueryAnchor (this) ">...</a>
              <input type=hidden name=tag>
            </template>
        <!-- XXX メイン言語でのテキスト -->
        <!-- XXX disable untill document.trLangKeys is available -->
      </table>
        <p class=buttons><button type=submit>追加</button>
        <p class=help><a href="/help#add" rel=help target=help>How to add lots of texts at once</a>
    </form>
</details>

<script src=/js/time.js charset=utf-8></script>
<script src=/js/core.js charset=utf-8></script>
<script>
  function escapeQueryValue (v) {
    return '"' + v.replace (/([\u0022\u005C])/g, function (x) { return '\\' + x }) + '"';
  } // escapeQueryValue

  function isEditMode () {
    return !!document.querySelector ('.dialog:not([hidden]):not(#config-langs), .toggle-edit.active, .edit-mode');
  } // isEditMode

  function setCurrentLangs (langKeys, langs) {
    var mainTable = document.getElementById ('texts');
    Array.prototype.slice.call (mainTable.querySelectorAll ('thead > tr > .lang-header')).forEach (function (cell) {
      if (cell.trResizeCSS && cell.trResizeCSS.parentNode) {
        cell.trResizeCSS.parentNode.removeChild (cell.trResizeCSS);
      }
      cell.parentNode.removeChild (cell);
    });
    var template = mainTable.querySelector ('thead > tr > .lang-header-template');
    langKeys.forEach (function (langKey) {
      var lang = langs[langKey];
      var th = document.createElement ('th');
      th.innerHTML = template.innerHTML;
      th.abbr = lang.label_short;
      th.className = 'lang-header';
      th.setAttribute ('data-lang', lang.key);
      th.querySelector ('.lang-label').textContent = lang.label;
      var sel = th.querySelector ('hr.resizer[data-td-selector]');
      if (sel) {
        sel.setAttribute ('data-td-selector', sel.getAttribute ('data-td-selector').replace (/\{lang_key\}/g, langKey));
      }
      template.parentNode.insertBefore (th, template);
      resizer (th);
    });
    Array.prototype.forEach.call (mainTable.querySelectorAll ('th[data-colspan-delta], td[data-colspan-delta]'), function (cell) {
      cell.colSpan = langKeys.length + parseInt (cell.getAttribute ('data-colspan-delta'));
    });
    document.trLangKeys = langKeys;
    document.trLangs = langs;
  } // setCurrentLangs

  function updateTagsArea (tagsArea, tags) {
    var tagTemplate = tagsArea.querySelector ('template');
    var tagsContainer = tagsArea.querySelector ('.tags');
    tagsContainer.textContent = '';
    tags.forEach (function (tag) {
      var div = document.createElement ('div');
      div.innerHTML = tagTemplate.innerHTML;
      var t = div.querySelector ('.tag');
      t.textContent = tag;
      t.href = './?tag=' + encodeURIComponent (tag);
      t.setAttribute ('data-query', 'tag:' + escapeQueryValue (tag));
      var input = div.querySelector ('input[name=tag]');
      if (input) input.value = tag;
      Array.prototype.slice.call (div.childNodes).forEach (function (node) {
        tagsContainer.appendChild (node);
      });
    });
    tagsArea.hidden = !(tags.length > 0);
  } // updateTagsArea

  function showTextMetadata (textId, text, area) {
    var tid = area.querySelector ('.text_id');
    tid.href = './?text_id=' + encodeURIComponent (textId);
    tid.setAttribute ('data-query', 'text_id:' + escapeQueryValue (textId));
    tid.querySelector ('code').textContent = textId;

    if (text.msgid) {
      var mid = area.querySelector ('.msgid');
      mid.href = './?msgid=' + encodeURIComponent (text.msgid);
      mid.setAttribute ('data-query', 'msgid:' + escapeQueryValue (text.msgid));
      mid.querySelector ('code').textContent = text.msgid;
    }

    area.querySelector ('.desc').textContent = text.desc || '';

    var tagsArea = area.querySelector ('.tags-area');
    updateTagsArea (tagsArea, text.tags || []);

    var argsArea = area.querySelector ('.args-area');
    var argTemplate = argsArea.querySelector ('template');
    var argsContainer = argsArea.querySelector ('.args');
    argsContainer.textContent = '';
    (text.args || []).forEach (function (argName) {
      var div = document.createElement ('div');
      div.innerHTML = argTemplate.innerHTML;
      div.querySelector ('.arg_name').textContent = argName;
      div.querySelector ('.arg_desc').textContent = text["args.desc."+argName] || "";
      Array.prototype.slice.call (div.childNodes).forEach (function (node) {
        argsContainer.appendChild (node);
      });
    });
    argsArea.hidden = !((text.args || []).length > 0);
  } // showTextMetadata

  function scrollToLangOrCommentsArea (cell) {
    var row = cell.parentNode;
    var headerRow = row.previousElementSibling;
    var headerTop = headerRow.offsetParent.offsetTop + headerRow.offsetTop;
    if (headerTop < document.body.scrollTop) {
      document.body.scrollTop = headerTop;
    } else {
      var menu = cell.querySelector ('.texts-lang-area-menu, .texts-comments-area-menu');
      var bottom = row.offsetTop + row.offsetParent.offsetTop + row.offsetHeight + (menu ? menu.offsetHeight : 0);
      var vpHeight = document.documentElement.clientHeight;
      if (document.body.scrollTop + vpHeight < bottom) {
        document.body.scrollTop = bottom - vpHeight;
      }
    }
  } // scrollToLangOrCommentsArea

  function toggleLangOrCommentsAreaEdit (area, mode) {
    if (mode === undefined) {
      area.classList.toggle ('edit-mode');
    } else {
      area.classList.toggle ('edit-mode', mode);
    }
    var editMode = area.classList.contains ('edit-mode');
    Array.prototype.forEach.call (area.querySelectorAll ('.toggle-edit'), function (el) {
      el.classList.toggle ('active', editMode);
    });
    if (editMode) {
      scrollToLangOrCommentsArea (area);
      Array.prototype.filter.call (area.querySelectorAll ('.edit p[data-form], .new-comment .edit p'), function (el) {
        return getComputedStyle (el).style !== 'none';
      })[0].querySelector ('textarea').focus ();
    }
  } // toggleLangOrCommentsAreaEdit

  function addTexts (iTexts) {
    var mainTable = document.getElementById ('texts');
    var rowContainer = mainTable.querySelector ('tbody');
    var rowTemplate = mainTable.querySelector ('.text-row-template');
    var langKeys = document.trLangKeys;
    var langs = document.trLangs;
    var langAreaTemplate = mainTable.querySelector ('.lang-area-template');

    var texts = [];
    for (var textId in iTexts) (function (text) {
      text.textId = textId;
      texts.push (text);
    }) (iTexts[textId]);
    texts.sort (function (a, b) {
      var aMsgid = a.msgid || '';
      var bMsgid = b.msgid || '';
      return aMsgid > bMsgid ? 1 : aMsgid < bMsgid ? -1 :
             a.textId > b.textId ? 1 : a.textId < b.textId ? -1 : 0;
    }).forEach (function (text) {
      var fragment = document.createElement ('tbody');
      fragment.innerHTML = rowTemplate.innerHTML;

      showTextMetadata (text.textId, text, fragment.querySelector ('.text-header > th'));

      var langAreaPlaceholder = fragment.querySelector ('.lang-area-placeholder');
      langKeys.forEach (function (langKey) {
        var area = document.createElement ('td');
        area.innerHTML = langAreaTemplate.innerHTML;
        area.className = 'lang-area';
        area.setAttribute ('data-lang', langKey);

        Array.prototype.forEach.call (area.querySelectorAll ('input.lang-key'), function (input) {
          input.value = langKey;
        });
        Array.prototype.forEach.call (area.querySelectorAll ('.lang-label-short'), function (el) {
          el.textContent = document.trLangs[langKey].label_short;
        });

        area.ondblclick = function (ev) {
          if (ev.target.form) return;
          toggleLangOrCommentsAreaEdit (area);
        };
        area.querySelector ('form.edit').onsubmit = function () {
          toggleLangOrCommentsAreaEdit (area, false);
          Array.prototype.forEach.call (area.querySelectorAll ('[type=submit]'), function (el) {
            el.disabled = true;
          });

          var formStatus = area.querySelector ('.status');
          showProgress ({init: true}, formStatus);

          var form = area.querySelector ('form');
          server ('POST', form.action, new FormData (form), function (res) {
            syncLangAreaView (area);
            formStatus.hidden = true;
            Array.prototype.forEach.call (area.querySelectorAll ('[type=submit]'), function (el) {
              el.disabled = false;
            });
          }, function (json) {
            toggleLangOrCommentsAreaEdit (area, true);
            showError (json, formStatus);
            Array.prototype.forEach.call (area.querySelectorAll ('[type=submit]'), function (el) {
              el.disabled = false;
            });
          }, function (json) {
            showProgress (json, formStatus);
          });
          return false;
        };

        var langData = text.langs ? text.langs[langKey] : null;
        var form = area.querySelector ('form.edit');
        if (langData) {
          if (langData.body_0) form.querySelector ('[name=body_0]').value = langData.body_0;
          if (langData.body_1) form.querySelector ('[name=body_1]').value = langData.body_1;
          if (langData.body_2) form.querySelector ('[name=body_2]').value = langData.body_2;
          if (langData.body_3) form.querySelector ('[name=body_3]').value = langData.body_3;
          if (langData.body_4) form.querySelector ('[name=body_4]').value = langData.body_4;
          if (langData.forms) form.querySelector ('[name=forms]').value = langData.forms;
        }

        form.querySelector ('select[name=forms]').onchange = function () {
          syncLangAreaTabs (area);
        };

        syncLangAreaView (area);

        langAreaPlaceholder.parentNode.insertBefore (area, langAreaPlaceholder);
      }); // langKey

      var comments = fragment.querySelector ('.comments-area');
      comments.ondblclick = function (ev) {
        if (ev.target.form) return;
        toggleLangOrCommentsAreaEdit (comments);
      };
      var commentForm = comments.querySelector ('form');
      commentForm.onsubmit = function () {
        var status = comments.querySelector ('.status');
        showProgress ({init: true}, status);
        var saveButton = commentForm.querySelector ('[type=submit]');
        saveButton.disabled = true;
        server ('POST', commentForm.action, new FormData (commentForm), function (res) {
          syncTextComments (comments, res.data.comments);
          status.hidden = true;
          saveButton.disabled = false;
          commentForm.reset ();
          toggleLangOrCommentsAreaEdit (comments, false);
        }, function (json) {
          showError (json, status);
          saveButton.disabled = false;
        }, function (json) {
          showProgress (json, status);
        });
        return false;
      }; // onsubmit
      if (text.comments && text.comments.length) {
        syncTextComments (comments, text.comments);
      }

      Array.prototype.forEach.call (fragment.querySelectorAll ('form[data-action]'), function (el) {
        el.action = el.getAttribute ('data-action').replace (/\{text_id\}/g, text.textId);
      });

      Array.prototype.forEach.call (fragment.querySelectorAll ('th[data-colspan-delta], td[data-colspan-delta]'), function (cell) {
        cell.colSpan = document.trLangKeys.length + parseInt (cell.getAttribute ('data-colspan-delta'));
      });
          
      Array.prototype.slice.call (fragment.children).forEach (function (el) {
        el.setAttribute ('data-text-id', text.textId);
        rowContainer.appendChild (el);
      });
    });
  } // addTexts

  // Cell selection
  (function () {
    var mainTable = document.querySelector ('#texts');
    var langMenu = document.querySelector ('.texts-lang-area-menu');
    var commentsMenu = document.querySelector ('.texts-comments-area-menu');
    mainTable.addEventListener ('click', function (ev) {
      if (ev.detail !== 1) return;
      var t = ev.target;
      while (t && t.localName !== 'td') {
        t = t.parentNode;
      }
      if (!t || t.localName !== 'td') return;
      var cell = t;
      var cellType;
      var menu;
      if (cell.classList.contains ('selected')) return;
      if (t.classList.contains ('lang-area')) {
        cellType = 'lang';
        menu = langMenu;
        commentsMenu.hidden = true;
      } else if (t.classList.contains ('comments-area')) {
        cellType = 'comments';
        menu = commentsMenu;
        langMenu.hidden = true;
      } else {
        return;
      }
      var oldCell = mainTable.querySelector ('td.selected');
      if (oldCell) {
        oldCell.classList.remove ('selected');
        oldCell.parentNode.classList.remove ('selected');
      }
      if (!cell) return;
      cell.classList.add ('selected');
      var row = cell.parentNode;
      row.classList.add ('selected');

      if (cellType === 'lang') {
        var langKey = cell.getAttribute ('data-lang');
        var textId = row.getAttribute ('data-text-id');
        Array.prototype.forEach.call (langMenu.querySelectorAll ('.lang-label'), function (el) {
          el.textContent = document.trLangs[langKey].label;
        });
        langMenu.querySelector ('.search').onclick = function () {
          showSearchSidebar (cell.querySelector ('[name=body_0]').value);
          return false;
        };
        Array.prototype.forEach.call (langMenu.querySelectorAll ('a[data-href]'), function (el) {
          el.href = el.getAttribute ('data-href').replace (/\{text_id\}/g, textId).replace (/\{lang_key\}/g, langKey);
        });
      } // cellType

      var editButton = menu.querySelector ('.toggle-edit');
      editButton.onclick = function () {
        toggleLangOrCommentsAreaEdit (cell);
        return false;
      };
      editButton.classList.toggle ('active', cell.classList.contains ('edit-mode'));

      menu.hidden = false;
      cell.appendChild (menu);
      scrollToLangOrCommentsArea (cell);
    });
  }) ();

function updateTable () {
  var mainTable = document.getElementById ('texts');
  var mainTableData = mainTable.tBodies[0];
  mainTableData.hidden = true;
  mainTableData.textContent = '';
  var mainTableStatus = mainTable.querySelector ('tbody.status');
  showProgress ({message: "Loading...", init: true}, mainTableStatus);

  var item = document.querySelector ('[itemtype=data]');
  var url = item.querySelector ('[itemprop=data-url]').href;
  var langQuery = item.querySelector ('[itemprop=lang-params]').content;
  if (langQuery) langQuery = '&' + langQuery;
  url += langQuery;
  var form = item.querySelector ('form');
  var query = form.elements.q.value;
  server ('POST', url, new FormData (form), function (res) {
    var json = res.data;
        var scopes = [];
        for (var scope in json.scopes) {
          scopes.push (scope);
        }
        document.documentElement.setAttribute ('data-scopes', scopes.join (' '));
        document.querySelector ('.if-readonly').hidden = json.scopes.edit;
        setCurrentLangs (json.selected_lang_keys, json.langs);
        addTexts (json.texts);
        var tagsArea = document.querySelector ('#add .tags-area');
        updateTagsArea (tagsArea, json.query.tags);
        mainTableData.hidden = false;
        mainTableStatus.hidden = true;
        history.replaceState (null, null, './?q=' + encodeURIComponent (query) + langQuery);
  }, function (json) {
    showError (json, mainTableStatus);
  }, function (json) {
    showProgress (json, mainTableStatus);
  });
  return false;
} // updateTable
document.querySelector ('[itemtype=data] form').onsubmit = function () {
  if (isEditMode ()) {
    if (!confirm ('保存していない編集を破棄します')) return false;
  }
  return updateTable ();
};
updateTable ();

function openQueryAnchor (el) {
  if (isEditMode ()) {
    if (!confirm ('保存していない編集を破棄します')) return false;
  }
  document.querySelector ('[itemtype=data] form input[name=q]').value = el.getAttribute ('data-query');
  return updateTable ();
} // openQueryAnchor

function syncLangAreaView (area) {
  var edit = area.querySelector ('form.edit');
  var view = area.querySelector ('.view');
  view.querySelector ('.body_0').textContent = edit.querySelector ('[name=body_0]').value;
  view.querySelector ('.body_1').textContent = edit.querySelector ('[name=body_1]').value;
  view.querySelector ('.body_2').textContent = edit.querySelector ('[name=body_2]').value;
  view.querySelector ('.body_3').textContent = edit.querySelector ('[name=body_3]').value;
  view.querySelector ('.body_4').textContent = edit.querySelector ('[name=body_4]').value;
  syncLangAreaTabs (area);
} // syncLangAreaView

function syncLangAreaTabs (area) {
  var edit = area.querySelector ('form.edit');
  var forms = edit.querySelector ('[name=forms]');
  var formsValue = forms.value;
  var formsFields = forms.selectedOptions[0].getAttribute ('data-fields').split (/,/);
  var hasFormsFields = {};
  formsFields.forEach (function (v) {
    hasFormsFields[v] = true;
  });
  area.setAttribute ('data-selected-form', formsFields[0]);
  var tabses = area.querySelectorAll ('.text-form-tabs');
  Array.prototype.forEach.call (tabses, function (el) {
    el.hidden = !(formsFields.length > 1);
  });
  Array.prototype.forEach.call (area.querySelectorAll ('.text-form-tabs > span[data-form]'), function (el) {
    var form = el.getAttribute ('data-form');
    el.hidden = !hasFormsFields[form];
  });
} // syncLangAreaView

function syncTextComments (commentsEl, textComments) {
  var commentTemplate = commentsEl.querySelector ('template');
  var commentParent = commentsEl.querySelector ('.comments-container');
  textComments.forEach (function (comment) {
    var df = document.createElement ('div');
    df.innerHTML = commentTemplate.innerHTML;
    df.querySelector ('.author_name').textContent = comment.author_name;
    df.querySelector ('.body').textContent = comment.body;
    df.querySelector ('time').setAttribute ('datetime', new Date (comment.last_modified * 1000).toISOString ());
    new TER.Delta (df);
    Array.prototype.slice.call (df.childNodes).forEach (function (n) {
      commentParent.appendChild (n);
    });
  });
} // syncTextComments
</script>

</section>

<aside class=sidebar hidden>
  <hr class=resizer tabindex=0 onclick=" parentNode.hidden = !parentNode.hidden; document.documentElement.classList.toggle ('has-sidebar', !parentNode.hidden) " title="サイドバーの表示の切り替え">
  <script type=text/plain class=resize-css>
.sidebar {
  width: %%WIDTH%%;
}

.has-sidebar body > section {
  margin-left: %%WIDTH%%;
}

.has-sidebar body > footer {
  margin-left: %%WIDTH%%;
}
  </script>
  <section id=sidebar-search>
    <header>
      <h1>用例を探す</h1>
      <button type=button class=close title="閉じる">閉じる</button>
    </header>
    <form action=/searchXXX method=get>
      <input type=search name=q placeholder=検索語句>
      <button type=submit>Search</button>
    </form>
    <p class=status hidden><progress></progress> <span class=message></span>
    <ul class=search-result>
    </ul>
    <template class=search-result-template>
      <div class=langs></div>
      <template class=lang-template>
        <p><strong class=lang>Language</strong>: <span class=text>Text</span>
      </template>
      <p class=source><a class=repo target=_blank>repo</a> / <a class=license target=license>LICENSE</a>
    </template>
    <!-- Filter by langs -->
    <script>
      function showSearchSidebar (q) {
        var sidebar = document.querySelector ('body > .sidebar');
        if (sidebar.hidden) sidebar.querySelector ('hr').click ();
        if (q) {
          sidebar.querySelector ('input[name=q]').value = q;
          sidebar.querySelector ('form').onsubmit ();
        }
      } // showSearchSidebar

      document.querySelector ('#sidebar-search button.close').onclick = function () {
        document.querySelector ('body > .sidebar > hr').click ();
      };
      document.querySelector ('#sidebar-search form').onsubmit = function () {
        var search = document.querySelector ('#sidebar-search');
        var q = search.querySelector ('input[name=q]').value;
        if (!q) return;
        var status = search.querySelector ('.status');
        status.hidden = false;
        status.querySelector ('.message').textContent = 'Searching...';
        var xhr = new XMLHttpRequest;
        xhr.open ('GET', '/search.json?q=' + encodeURIComponent (q), true);
        xhr.onreadystatechange = function () {
          if (xhr.readyState === 4) {
            if (xhr.status === 200) {
              var results = JSON.parse (xhr.responseText);
              var resultList = search.querySelector ('.search-result');
              var resultTemplate = search.querySelector ('.search-result-template');
              resultList.textContent = '';
              results.forEach (function (item) {
                var li = document.createElement ('li');
                li.innerHTML = resultTemplate.innerHTML;
                var langs = li.querySelector ('.langs');
                var t = li.querySelector ('.lang-template');
                for (var l in item.preview) {
                  var div = document.createElement ('div');
                  div.innerHTML = t.innerHTML;
                  div.querySelector ('.lang').textContent = l;
                  var text = div.querySelector ('.text'); // XXX if long,
                  var rt = item.preview[l] || "";
                  var i = rt.indexOf (q);
                  if (i > -1) {
                    text.textContent = rt.substring (0, i);
                    text.appendChild (document.createElement ('mark'))
                        .textContent = q;
                    text.appendChild (document.createTextNode (rt.substring (i + q.length)));
                  } else {
                    text.textContent = rt;
                  }
                  Array.prototype.slice.call (div.childNodes).forEach (function (node) {
                    langs.appendChild (node);
                  });
                }
                var repoName = item.repo_url.split (/\//);
                repoName = repoName[repoName.length-1];
                var repoPage = '/tr/' + encodeURIComponent (item.repo_url) + '/' + encodeURIComponent (item.repo_branch) + '/' + encodeURIComponent (item.repo_path) + '/';
                li.querySelector ('.source .repo').textContent = repoName;
                li.querySelector ('.source .repo').href = repoPage + '?text_id=' + encodeURIComponent (item.text_id);
                li.querySelector ('.source .license').textContent = item.repo_license || 'Unknown'; // XXX human-readable abbrev
                li.querySelector ('.source .license').href = repoPage + 'LICENSE';
                resultList.appendChild (li);
              });

              // XXX paging
            } else {
              // XXX
            }
            status.hidden = true;
          }
        };
        xhr.send (null);
        return false;
      };
    </script>
  </section>
</aside>

<script>
  document.trDialogHandlers = {};

    function modalDialog (id, show, args) {
      var dialogRoot = document.getElementById (id);
      var handler = document.trDialogHandlers[id] || {};
      if (!handler._initialized) {
        Array.prototype.forEach.call (dialogRoot.querySelectorAll ('.close'), function (button) {
          button.onclick = function () {
            modalDialog (id, false);
          };
        });
        handler._initialized = true;
      }
      if (show) {
        if (handler.beforeshow) handler.beforeshow (dialogRoot, args);
        dialogRoot.style.top = document.body.scrollTop + 'px';
        dialogRoot.hidden = false;
        if (handler.navigatable) {
          history.replaceState (null, null, '#' + id);
        }
      } else {
        dialogRoot.hidden = true;
        if (location.hash === '#' + id) {
          history.replaceState (null, null, '#');
        }
      }
    } // modalDialog
</script>

<div class=dialog id=config-langs hidden>
  <section>
    <header>
      <h1>言語設定</h1>
      <button type=button class=close title="閉じる">閉じる</button>
    </header>

    <ul class=langs />
    <template class=lang-template><!-- data-lang={lang_key} -->
      <label>
        <input type=checkbox>
        <span class=lang-label>{lang_label}</span>
      </label>
      <button type=button class=up-button>上に移動</button>
      <button type=button class=down-button>下に移動</button>
    </template>
    <p class=buttons>
      <button type=button class=apply-button>選択した言語を表示</button>

    <hr>

    <p><a href="langs" target=config class=close>対象言語の設定</a>

    <p class=status hidden><progress></progress> <span class=message></span>
  </section>
  <script>
    document.trDialogHandlers['config-langs'] = {navigatable: true};
    document.trDialogHandlers['config-langs'].beforeshow = function (root) {
        // XXX wait until document.trLangKeys available
        var list = root.querySelector ('.langs');
        var template = root.querySelector ('.lang-template');
        Array.prototype.slice.call (list.querySelectorAll ('li')).forEach (function (li) {
          list.removeChild (li);
        });
        var langKeys = [];
        var isSelected = {};
        document.trLangKeys.forEach (function (_) { isSelected[_] = true; langKeys.push (_) });
        for (var lang in document.trLangs) {
          if (!isSelected[lang]) langKeys.push (lang);
        }
        langKeys.forEach (function (langKey) {
          var lang = document.trLangs[langKey];
          var li = document.createElement ('li');
          li.innerHTML = template.innerHTML;
          li.setAttribute ('data-lang', langKey);
          li.querySelector ('.lang-label').textContent = lang.label;
          li.querySelector ('input[type=checkbox]').checked = isSelected[langKey];
          li.querySelector ('.up-button').onclick = function () {
            var prev = li.previousElementSibling;
            if (prev) li.parentNode.insertBefore (li, prev);
          };
          li.querySelector ('.down-button').onclick = function () {
            var next = li.nextElementSibling;
            if (next) next.parentNode.insertBefore (next, li);
          };
          list.appendChild (li);
        });
        root.querySelector ('.apply-button').onclick = function () {
          var item = document.querySelector ('[itemtype=data]');
          item.querySelector ('[itemprop=lang-params]').content
              = Array.prototype.filter.call (root.querySelectorAll ('.langs > li[data-lang]'), function (li) { return li.querySelector ('input[type=checkbox]').checked })
              .map (function (li) { return 'lang=' + encodeURIComponent (li.getAttribute ('data-lang')) })
              .join ('&');
          updateTable ();
          modalDialog ('config-langs', false);
        };
    }; // beforeshow
  </script>
</div>

<div class="dialog share" id=share hidden>
  <section>
    <header>
      <h1>共有</h1>
      <button type=button class=close title="閉じる">閉じる</button>
    </header>

    <table class=config>
      <tr><th>全体<td><input class=copyable>
      <tr><th>現在の絞り込み<td><input class=copyable>
      <!-- XXX langs -->
    </table>
  </section>
  <script>
    document.trDialogHandlers['share'] = {navigatable: true};
    document.trDialogHandlers['share'].beforeshow = function (root) {
      var texts = root.querySelectorAll ('.copyable');
      texts[0].value = location.href.replace (/\?.*/, '');
      texts[1].value = location.href.replace (/#.*/, '');

      Array.prototype.forEach.call (texts, function (input) {
        input.onfocus = function () { this.select (0, this.value.length) };
      });
    }; // beforeshow
  </script>
</div>

<div class="dialog copy-id" id=copy-id hidden>
  <section>
    <header>
      <h1>テキストID</h1>
      <button type=button class=close title="閉じる">閉じる</button>
    </header>

    <table class=config>
      <tr><th>テキストID<td><input class=copyable data-value="{text_id}">
      <tr><th>メッセージID<td><input class=copyable data-value="{msgid}">
      <tr><th>TT<td><input class=copyable data-value="[% loc('{msgid}') %]">
      <!-- XXX repo-dependent templates -->
    </table>
  </section>
  <script>
    document.trDialogHandlers['copy-id'] = {};
    document.trDialogHandlers['copy-id'].beforeshow = function (root, args) {
      var textId = args.area.querySelector ('.text_id').textContent;
      var msgid = args.area.querySelector ('.msgid').textContent;

      Array.prototype.forEach.call (root.querySelectorAll ('input.copyable'), function (input) {
        var template = input.getAttribute ('data-value');
        input.parentNode.parentNode.hidden
            = (textId === "" && /\{text_id\}/.test (template)) ||
              (msgid === "" && /\{msgid\}/.test (template));
        input.value = template.replace (/\{text_id\}/g, textId).replace (/\{msgid\}/g, msgid);
        input.onfocus = function () { this.select (0, this.value.length) };
      });
    }; // beforeshow
  </script>
</div>

<div class="dialog config-text" id=config-text hidden>
  <section>
    <header>
      <h1>テキストの設定</h1>
      <button type=button class=close title="保存せず閉じる">閉じる</button>
    </header>

    <form data-action="i/{text_id}/meta.ndjson" method=post>
      <table class=config>
        <tbody>
          <tr>
            <th><label for=config-text-text-id>テキストID</label>
            <td><input name=text_id id=config-text-text-id readonly>
          <tr>
            <th><label for=config-text-msgid>メッセージID</label>
            <td><input name=msgid id=config-text-msgid>
          <tr>
            <th><label for=config-text-desc>簡単な説明</label>
            <td><input name=desc id=config-text-desc>
        <tbody>
          <tr>
            <th>タグ
            <td>
              <table class=tags>
                <template>
                  <th><input name=tag><td><button type=button onclick=" if (confirm (getAttribute ('data-confirm'))) this.parentNode.parentNode.parentNode.removeChild (this.parentNode.parentNode) " data-confirm="このタグを削除します">削除</button>
                </template>
                <tbody>
                <tfoot>
                  <tr>
                    <td><td><button type=button onclick="
                      var table = this.parentNode.parentNode.parentNode.parentNode;
                      var template = table.querySelector ('template');
                      var tr = document.createElement ('tr');
                      tr.innerHTML = template.innerHTML;
                      table.tBodies[0].appendChild (tr);
                    ">追加</button>
              </table>
        <tbody>
          <tr>
            <th>引数
            <td>
              <table class=args>
                <template>
                  <th>{<input name=arg_name></span>}
                  <td><input name=arg_desc></span>
                  <td><button type=button onclick=" if (confirm (getAttribute ('data-confirm'))) this.parentNode.parentNode.parentNode.removeChild (this.parentNode.parentNode) " data-confirm="この引数を削除します">削除</button>
                </template>
                <thead>
                  <tr>
                    <th>{変数名}
                    <th>短い説明
                    <th>
                <tbody>
                <tfoot>
                  <tr><th><td><td><button type=button onclick="
                    var table = this.parentNode.parentNode.parentNode.parentNode;
                    var template = table.querySelector ('template');
                    var tr = document.createElement ('tr');
                    tr.innerHTML = template.innerHTML;
                    table.tBodies[0].appendChild (tr);
                  ">追加</button>
              </table>
      </table>
      <p class=buttons><button type=submit class=save>保存して閉じる</button>
    </form>
    <p class=status hidden><progress></progress> <span class=message></span>
  </section>
  <script>
    document.trDialogHandlers['config-text'] = {};
    document.trDialogHandlers['config-text'].beforeshow = function (root, args) {
      var textId = args.area.querySelector ('.text_id').textContent;
      var form = root.querySelector ('form');
      form.action = form.getAttribute ('data-action').replace (/\{text_id\}/g, textId);
      form.onsubmit = function () {
        var status = root.querySelector ('.status');
        showProgress ({init: true}, status);
        var saveButton = root.querySelector ('.save');
        saveButton.disabled = true;
        
        server ('POST', form.action, new FormData (form), function (res) {
          showTextMetadata (textId, res.data, args.area);
          modalDialog ('config-text', false);
          status.hidden = true;
          saveButton.disabled = false;
        }, function (json) {
          showError (json, status);
          saveButton.disabled = false;
        }, function (json) {
          showProgress (json, status);
        });
        return false;
      };

      ['msgid', 'text_id', 'desc'].forEach (function (n) {
        root.querySelector ('[name='+n+']').value = args.area.querySelector ('.'+n+'').textContent;
      });

      var dialogTags = root.querySelector ('table.tags');
      var dialogTagsTemplate = dialogTags.querySelector ('template');
      var dialogTagsContainer = dialogTags.tBodies[0];
      dialogTagsContainer.textContent = '';
      Array.prototype.forEach.call (args.area.querySelectorAll ('.tag'), function (el) {
        var tr = document.createElement ('tr');
        tr.innerHTML = dialogTagsTemplate.innerHTML;
        tr.querySelector ('[name=tag]').value = el.textContent;
        dialogTagsContainer.appendChild (tr);
      });
      if (!dialogTagsContainer.firstChild) {
        var tr = document.createElement ('tr');
        tr.innerHTML = dialogTagsTemplate.innerHTML;
        dialogTagsContainer.appendChild (tr);
      }

      var dialogArgs = root.querySelector ('table.args');
      var dialogArgsTemplate = dialogArgs.querySelector ('template');
      var dialogArgsContainer = dialogArgs.tBodies[0];
      dialogArgsContainer.textContent = '';
      Array.prototype.forEach.call (args.area.querySelectorAll ('.arg'), function (el) {
        var tr = document.createElement ('tr');
        tr.innerHTML = dialogArgsTemplate.innerHTML;
        tr.querySelector ('[name=arg_name]').value = el.querySelector ('.arg_name').textContent;
        tr.querySelector ('[name=arg_desc]').value = el.querySelector ('.arg_desc').textContent;
        dialogArgsContainer.appendChild (tr);
      });
      if (!dialogArgsContainer.firstChild) {
        var tr = document.createElement ('tr');
        tr.innerHTML = dialogArgsTemplate.innerHTML;
        dialogArgsContainer.appendChild (tr);
      }
    }; // beforeshow
  </script>
</div>

<div class=dialog id=export hidden>
  <section>
    <header>
      <h1>Export</h1>
      <button type=button class=close title="閉じる">閉じる</button>
    </header>

    <form method=get target=_blank>
      <table class=config>
        <tr>
          <th><label for=export-lang>Language</label>
          <td>
            <select id=export-lang name=lang>
              <!-- XXX -->
              <option value=en label=English>
              <option value=ja label=Japanese>
            </select>
        <tr>
          <th><label for=export-format>Output format</label>
          <td>
            <select id=export-format name=format>
              <option value=po>PO (GNU Gettext)
            </select>
        <tr>
          <th><label for=export-arg_format>Argument format</label>
          <td>
            <select id=export-arg_format name=arg_format>
              <option value=auto>Default
              <option value=printf>printf
              <option value=percentn>%n
              <option value=braced>{placeholder}
            </select>
        <tr>
          <td colspan=2>
            <p><label><input type=checkbox name=no_fallback> Disable fallback for missing texts</label>
            <p><label><input type=checkbox name=preserve_html> Preserve HTML markup</label>
      </table>
      <p class=buttons><button type=submit>Export</button>
    </form>
  </section>
  <script>
    document.trDialogHandlers['export'] = {navigatable: true};
    document.trDialogHandlers['export'].beforeshow = function (root) {
      var item = document.querySelector ('[itemtype=data]');
      var url = item.querySelector ('[itemprop=export-url]').href;
      root.querySelector ('form').action = url;
    }; // beforeshow
  </script>
</div>

<script>
  function resizer (root) {
    Array.prototype.forEach.call (root.querySelectorAll ('hr.resizer'), function (resizer) {
      var resized = resizer.parentNode;
      resizer.onmousedown = function (ev) {
        document.trCurrentResizer = resizer;
        document.trResizeStart = (new Date).valueOf ();
        document.trTransparent = document.createElement ('div');
        document.trTransparent.className = 'resizer-transparent';
        document.body.appendChild (document.trTransparent);
        resizer.classList.add ('resizing');
        document.documentElement.classList.add ('resizing');
        var style = resized.trResizeCSS;
        if (!style) {
          var cssTemplate = resized.querySelector ('.resize-css');
          if (cssTemplate) {
            style = resized.trResizeCSS = document.createElement ('style');
            style.trTemplate = cssTemplate.textContent.replace (/%%SELECTOR%%/g, resizer.getAttribute ('data-td-selector'));
            style.textContent = style.trTemplate.replace (/%%WIDTH%%/g, '10rem');
            document.body.appendChild (style);
          }
        }
        if (resized.trResizeStyle !== "") {
          resized.trResizeStyle = resizer.getAttribute ('data-th-style') || "";
        }
        if (resized.hidden) {
          resizer.onclick ();
          resizer.trResize (ev);
        }
      }; // onmousedown
      resizer.onselectstart = function () { return false };
      resizer.trResize = function (ev) {
        if (document.trResizeStart + 200 > (new Date).valueOf ()) return;
        var resizedWidth = ev.pageX - resized.offsetLeft;
        if (resizedWidth < 16) resizedWidth = 16;
        if (resized.trResizeCSS) {
          resized.trResizeCSS.textContent = resized.trResizeCSS.trTemplate.replace (/%%WIDTH%%/g, resizedWidth + 'px');
        }
        if (resized.trResizeStyle !== "") {
          resized.setAttribute ("style", resized.trResizeStyle.replace (/%%WIDTH%%/g, resizedWidth + 'px'));
        }
      };
    });
    addEventListener ('mousemove', function (ev) {
      if (document.trCurrentResizer) {
        document.trCurrentResizer.trResize (ev);
      }
    });
    addEventListener ('mouseup', function () {
      if (document.trCurrentResizer) {
        document.documentElement.classList.remove ('resizing');
        document.trCurrentResizer.classList.remove ('resizing');
        document.trCurrentResizer = null;
        document.trTransparent.parentNode.removeChild (document.trTransparent);
      }
    });
  } // resizer
  resizer (document.body);
</script>

<script>
  var f = decodeURIComponent (location.hash.replace (/^#/, ''));
  if (document.trDialogHandlers[f] && document.trDialogHandlers[f].navigatable) {
    modalDialog (f, true);
  }
</script>

<t:include path=_footer.html.tm m:app=$app />
