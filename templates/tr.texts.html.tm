<html t:params="$tr $data_params $app $query">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" if (isEditMode ()) return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<header class=site>
<h1><a href="/" rel=index>TR</a></h1>

<nav>
  <a href="/help" rel=help>Help</a>
</nav>
</header>

<section>

<header class=textset itemscope itemtype=data>
  <hgroup> 
    <h1 title=Repository><a href="../../" rel="up up"><code itemprop=url><t:text value="$tr->url"></code></a></h1>
    <h2 title=Branch><a href="../" rel=up><code itemprop=branch><t:text value="$tr->branch"></code></a></h2>
    <h3 title=Path><a href="./" rel=bookmark><code itemprop=texts-path><t:text value="'/' . $tr->texts_dir"></code></a></h3>
  </hgroup>
  <link itemprop=data-url pl:href="'data.json?'.$data_params.'&with_comments=1'">
  <link itemprop=export-url pl:href="'export?'.$data_params">

  <nav class=langs-menu-container>
    <a href="#config-export" onclick=" toggleExportDialog (true) " class=import title="テキスト集合に外部データを取り込み">Import</a>
    <a href="#config-export" onclick=" toggleExportDialog (true) " class=export title="テキスト集合からデータファイルを生成">Export</a>
    <button type=button class=settings title="テキスト集合全体の設定を変更">設定</button>
    <menu hidden>
          <!-- XXX -->
          <t:for as=$lang x="$tr->avail_langs">
            <label><input type=checkbox pl:value=$lang> <t:text value=$lang></label>
          </t:for>
          <hr>
          <a href="#config-langs" onclick=" toggleLangsConfig (true) ">言語設定...</a>
    </menu>
  </nav>

  <form action="./" method=get class=filter>
    <p>
      <input type=search name=q pl:value="$query->stringify" placeholder="Filtering by words">
      <button type=submit>Apply</button>
      <a href="/help/filtering" rel=help title="Filter syntax" target=help>Help</a>
    <!-- XXX langs -->
  </form>
</header>

<table id=texts pl:data-all-langs="join ',', @{$tr->avail_langs}">
  <t:my as=$lang_cell_count x="0+@{$tr->langs}">
  <thead>
    <tr>
      <t:for as=$lang x="$tr->langs">
        <th><t:text value=$lang>
      </t:for>
      <th>コメント
  </thead>
  <template class=text-header-template>
    <tr class=text-header>
      <th pl:colspan="$lang_cell_count+1">
        <a class=msgid onclick=" showCopyIdDialog (this.parentNode); return false "><code></code></a>
        <a class=text_id onclick=" showCopyIdDialog (this.parentNode); return false "><code></code></a>
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
        <span class=buttons><button type=button class=edit title="テキスト情報を編集" onclick=" showTextEditDialog (parentNode.parentNode) ">編集</button></span>
    <tr class=text-body>
      <t:for as=$lang x="$tr->langs">
        <td pl:data-lang=$lang class=lang-area>
          <p class=header>
            <strong class=lang><t:text value=$lang></strong>
            <button type=button class=toggle-edit title=Edit>Edit</button>
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
          <p class=status hidden><progress></progress> <span class=message></span>
          <form data-action="i/{text_id}/" method=post class=edit hidden>
            <p class=buttons><button type=submit>保存</button>
            <input type=hidden name=lang pl:value=$lang>
            <!-- XXX hash -->
            <p data-form=0><textarea name=body_0></textarea>
            <p data-form=1><textarea name=body_1></textarea>
            <p data-form=2><textarea name=body_2></textarea>
            <p data-form=3><textarea name=body_3></textarea>
            <p data-form=4><textarea name=body_4></textarea>
            <menu class=text-form-tabs>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=0>0</span>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=1>1</span>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=2>2</span>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=3>3</span>
              <span onclick="parentNode.parentNode.parentNode.setAttribute('data-selected-form', getAttribute ('data-form'))" tabindex=0 data-form=4>4</span>
            </menu>
            <p>
              <select name=forms>
                <option value=o data-fields=0>Only the default form
                <option value=1o data-fields=0,1>Singular (1) and plural
                <option value=0o data-fields=0,1>Singular (0, 1) and plural
                <option value=test data-fields=0,2,3,4>Test
              </select>
            <p class=links><a pl:data-href="'i/{text_id}/history.json?lang='.$lang #XXX percent-encode ?" target=history>History</a>
          </form>
      </t:for>

      <td class=comments-area>
        <p class=header><button type=button class=toggle-edit title="コメントを書く">コメントを書く</button>
        <div class=comments-container></div>
        <template>
          <article>
            <p class=body>
            <footer><p><time></time></footer>
          </article>
        </template>
        <div class=new-comment>
          <div class=view>
          </div>
          <form data-action="i/{text_id}/comments" method=post class=edit hidden>
            <p><textarea name=body></textarea>
            <p class=buttons><button type=submit>投稿</button>
          </form>
          <p class=status hidden><progress></progress> <span class=message></span>
        </div>
  </template> 
  <tbody>
  <tbody class=status hidden>
    <tr>
      <td pl:colspan="$lang_cell_count+1">
        <progress></progress> <span class=message></span>
  <tfoot>
    <tr id=add>
      <td pl:colspan="$lang_cell_count+1">

    <form action=add method=post onsubmit="
  var form = this;
  form.hidden = true;
  var mainTable = document.getElementById ('texts');
  var mainTableStatus = mainTable.querySelector ('tbody.status');
  mainTableStatus.hidden = false;
  mainTableStatus.querySelector ('.message').textContent = 'Adding...';

  var xhr = new XMLHttpRequest;
  xhr.open ('POST', form.action, true);
  var fd = new FormData (form);
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      if (xhr.status < 400) {
        var json = JSON.parse (xhr.responseText);
        addTexts (json.texts);
        form.reset ();
      } else { // XXX
      }
      mainTableStatus.hidden = true;
      form.hidden = false;
    }
  };
  xhr.send (fd);
  return false;
    ">
      <details>
        <summary>メッセージの追加</summary>
      <table class=config>
        <tr>
          <th><label for=add-msgid>メッセージID</label>
          <td><input type=text name=msgid pl:value="$app->text_param ('msgid') // ''" id=add-msgid>
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
      </table>
      <p class=buttons><button type=submit>追加</button>
      </details>
    </form>
</table>

<script src=/js/time.js charset=utf-8></script>
<script>
  function escapeQueryValue (v) {
    return '"' + v.replace (/([\u0022\u005C])/g, function (x) { return '\\' + x }) + '"';
  } // escapeQueryValue

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

function isEditMode () {
  return !!document.querySelector ('.dialog:not([hidden]), .toggle-edit.active');
} // isEditMode

function addTexts (iTexts) {
  var mainTable = document.getElementById ('texts');
  var rowContainer = mainTable.querySelector ('tbody');
  var rowTemplate = mainTable.querySelector ('template.text-header-template');

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

    Array.prototype.map.call (fragment.querySelectorAll ('.lang-area[data-lang]'), function (area) {
      var toggle = area.querySelector ('button.toggle-edit');
      toggle.onclick = function () {
        toggleAreaEditor (area, !this.classList.contains ('active'));
      };
      area.querySelector ('form.edit').onsubmit = function () {
        toggleAreaEditor (area, false);
        return saveArea (area);
      };
      area.trSync = syncLangAreaView;

      var lang = area.getAttribute ('data-lang');
      var langData = text.langs ? text.langs[lang] : null;
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

      area.trSync (area);
    });

    var comments = fragment.querySelector ('.comments-area');
    comments.querySelector ('button.toggle-edit').onclick = function () {
      toggleAreaEditor (comments, !this.classList.contains ('active'));
    };
    var commentForm = comments.querySelector ('form');
    commentForm.onsubmit = function () {
      toggleAreaEditor (comments, false);
      return saveArea (comments);
    };
    comments.trSync = function () {
      var c = {body: commentForm.elements.body.value,
               last_modified: (new Date).valueOf () / 1000};
      syncTextComments (comments, [c]);
    };
    if (text.comments && text.comments.length) {
      syncTextComments (comments, text.comments);
    }

    Array.prototype.forEach.call (fragment.querySelectorAll ('form[data-action]'), function (el) {
      el.action = el.getAttribute ('data-action').replace (/\{text_id\}/g, text.textId);
    });
    Array.prototype.forEach.call (fragment.querySelectorAll ('a[data-href]'), function (el) {
      el.href = el.getAttribute ('data-href').replace (/\{text_id\}/g, text.textId);
    });
          
    Array.prototype.slice.call (fragment.children).forEach (function (el) {
      rowContainer.appendChild (el);
    });
  });
} // addTexts

function updateTable () {
  var mainTable = document.getElementById ('texts');
  var mainTableData = mainTable.tBodies[0];
  mainTableData.hidden = true;
  mainTableData.textContent = '';
  var mainTableStatus = mainTable.querySelector ('tbody.status');
  mainTableStatus.hidden = false;
  mainTableStatus.querySelector ('.message').textContent = 'Loading...';

  var item = document.querySelector ('[itemtype=data]');
  var url = item.querySelector ('[itemprop=data-url]').href;
  var form = item.querySelector ('form');
  var query = form.elements.q.value;
  var xhr = new XMLHttpRequest;
  xhr.open ('POST', url, true);
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      if (xhr.status < 400) {
        var json = JSON.parse (xhr.responseText);
        addTexts (json.texts);
        var tagsArea = document.querySelector ('#add .tags-area');
        updateTagsArea (tagsArea, json.query.tags);
        mainTableData.hidden = false;
        mainTableStatus.hidden = true;
        history.replaceState (null, null, './?q=' + encodeURIComponent (query)); // XXX lang=...
      } else {
        // XXX
      }
    }
  };
  xhr.send (new FormData (form));
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
    df.querySelector ('.body').textContent = comment.body;
    df.querySelector ('time').setAttribute ('datetime', new Date (comment.last_modified * 1000).toISOString ());
    new TER.Delta (df);
    Array.prototype.slice.call (df.childNodes).forEach (function (n) {
      commentParent.appendChild (n);
    });
  });
} // syncTextComments

function toggleAreaEditor (area, editMode) {
  var edit = area.querySelector ('form.edit');
  var view = area.querySelector ('.view');
  var toggle = area.querySelector ('button.toggle-edit');
  if (editMode) {
    edit.hidden = false;
    view.hidden = true;
  } else {
    view.hidden = false;
    edit.hidden = true;
  }
  area.classList.toggle ('edit-mode', editMode);
  toggle.classList.toggle ('active', editMode);
} // toggleAreaEditor

function saveArea (area, onsaved) { // XXX promise
  var formStatus = area.querySelector ('.status');
  formStatus.hidden = false;
  formStatus.querySelector ('.message').textContent = 'Saving...';
  var editButton = area.querySelector ('button.toggle-edit');
  if (editButton) editButton.disabled = true;

  var form = area.querySelector ('form');
  var xhr = new XMLHttpRequest;
  xhr.open ('POST', form.action, true);
  var fd = new FormData (form);
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      if (xhr.status < 400) {
        if (onsaved) onsaved (JSON.parse (xhr.responseText));
        if (area.trSync) area.trSync (area);
      } else { // XXX
      }
      formStatus.hidden = true;
      if (editButton) editButton.disabled = false;
    }
  };
  xhr.send (fd);
  return false;
} // saveArea
</script>

</section>

<div class=dialog id=config-langs hidden>
  <section>
    <header>
      <h1>言語設定</h1>
      <button type=button class=close title="保存せずに閉じる">閉じる</button>
    </header>

    <form action="langs" method=post>
      <ul>
        <t:for as=$lang x="$tr->avail_langs">
          <li>
            <span class=lang-id><t:text value=$lang></span>
            <input type=hidden name=lang pl:value=$lang>
        </t:for>
        <li class=lang-new>
          <template>
            <span class=lang-id></span><input type=hidden name=lang>
          </template>
          <table class=config>
            <tbody>
              <tr>
                <th>言語ID
                <td><input name=lang_id required>
              <tr>
                <th>言語タグ
                <td><input name=lang_tag required>
          </table>
          <p class=buttons><button type=button class=add>追加</button>
      </ul>

      <p class=buttons><button type=button class=save>保存して閉じる</button>
    </form>
    <p class=status hidden><progress></progress> <span class=message></span>
  </section>
  <script>
    function toggleLangsConfig (status) {
      var langsPanel = document.querySelector ('#config-langs');
      if (status) {
        langsPanel.hidden = false;
      } else {
        langsPanel.hidden = true;
      }
    } // toggleLangsConfig

      (function () {
        var langsMenuContainer = document.querySelector ('.langs-menu-container');
        var langsMenuButton = langsMenuContainer.querySelector ('button.settings');
        var langsMenu = langsMenuContainer.querySelector ('menu');
        langsMenuButton.onclick = function () {
          langsMenu.hidden = !langsMenu.hidden;
          langsMenuButton.classList.toggle ('active', !langsMenu.hidden);
          if (langsMenu.hidden) {
            history.replaceState (null, null, '#');
          }
        };
        Array.prototype.slice.call (langsMenu.querySelectorAll ('a')).forEach (function (a) {
          a.addEventListener ('click', function () {
            langsMenu.hidden = true;
            langsMenuButton.classList.remove ('active');
            history.replaceState (null, null, '#');
          });
        });

        var langsPanel = document.querySelector ('#config-langs');
        langsPanel.trSync = function () {
          // XXX enable lang setting
          toggleLangsConfig (false);
          history.replaceState (null, null, '#');
          // XXX sync langs in this page
        };
        langsPanel.querySelector ('button.save').onclick = function () {
          // XXX disable lang setting
          saveArea (langsPanel);
          // XXX enable lang setting if save failed
        };
        langsPanel.querySelector ('button.close').onclick = function () {
          toggleLangsConfig (false);
          history.replaceState (null, null, '#');
        };
        var newLang = langsPanel.querySelector ('.lang-new');
        var langTemplate = newLang.querySelector ('template');
        newLang.querySelector ('button.add').onclick = function () {
          var item = document.createElement ('li');
          item.innerHTML = langTemplate.innerHTML;
          var langID = newLang.querySelector ('input[name=lang_id]').value;
          var langTag = newLang.querySelector ('input[name=lang_tag]').value;
          if (langID && langTag) {
            item.querySelector ('.lang-id').textContent = langID;
            item.querySelector ('input[name=lang]').value = langTag;
            newLang.parentNode.insertBefore (item, newLang);
            newLang.querySelector ('input[name=lang_id]').value = '';
            newLang.querySelector ('input[name=lang_tag]').value = '';
          }
        };

        var f = decodeURIComponent (location.hash.replace (/^#/, ''));
        if (f === 'config-langs') {
          toggleLangsConfig (true);
        }
      }) ();
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
    function showCopyIdDialog (area) {
      var dialog = document.querySelector ('#copy-id');

      var textId = area.querySelector ('.text_id').textContent;
      var msgid = area.querySelector ('.msgid').textContent;

      dialog.querySelector ('button.close').onclick = hideCopyIdDialog;

      Array.prototype.forEach.call (dialog.querySelectorAll ('input.copyable'), function (input) {
        var template = input.getAttribute ('data-value');
        input.parentNode.parentNode.hidden
            = (textId === "" && /\{text_id\}/.test (template)) ||
              (msgid === "" && /\{msgid\}/.test (template));
        input.value = template.replace (/\{text_id\}/g, textId).replace (/\{msgid\}/g, msgid);
        input.onfocus = function () { this.select (0, this.value.length) };
      });

      dialog.hidden = false;
      dialog.style.top = document.body.scrollTop + 'px';
    } // showCopyIdDialog

    function hideCopyIdDialog () {
      var dialog = document.querySelector ('#copy-id');
      dialog.hidden = true;
    } // hideCopyIdDialog
  </script>
</div>

<div class="dialog config-text" id=config-text hidden>
  <section>
    <header>
      <h1>テキストの設定</h1>
      <button type=button class=close title="保存せず閉じる">閉じる</button>
    </header>

    <form data-action="i/{text_id}/meta" method=post>
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
    function showTextEditDialog (area) {
      var dialog = document.querySelector ('#config-text');

      var textId = area.querySelector ('.text_id').textContent;
      var form = dialog.querySelector ('form');
      form.action = form.getAttribute ('data-action').replace (/\{text_id\}/g, textId);

      dialog.querySelector ('button.close').onclick = hideTextEditDialog;
      form.onsubmit = function () {
        return saveArea (dialog, function (text) {
          showTextMetadata (textId, text, area);
          hideTextEditDialog ();
        });
      };

      ['msgid', 'text_id', 'desc'].forEach (function (n) {
        dialog.querySelector ('[name='+n+']').value = area.querySelector ('.'+n+'').textContent;
      });

      var dialogTags = dialog.querySelector ('table.tags');
      var dialogTagsTemplate = dialogTags.querySelector ('template');
      var dialogTagsContainer = dialogTags.tBodies[0];
      dialogTagsContainer.textContent = '';
      Array.prototype.forEach.call (area.querySelectorAll ('.tag'), function (el) {
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

      var dialogArgs = dialog.querySelector ('table.args');
      var dialogArgsTemplate = dialogArgs.querySelector ('template');
      var dialogArgsContainer = dialogArgs.tBodies[0];
      dialogArgsContainer.textContent = '';
      Array.prototype.forEach.call (area.querySelectorAll ('.arg'), function (el) {
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

      dialog.hidden = false;
      dialog.style.top = document.body.scrollTop + 'px';
    } // showTextEditDialog

    function hideTextEditDialog () {
      var dialog = document.querySelector ('#config-text');
      dialog.hidden = true;
    } // hideTextEditDialog
  </script>
</div>

<div class=dialog id=config-export hidden>
  <section>
    <header>
      <h1>Export</h1>
      <button type=button class=close onclick=" toggleExportDialog (false) ">閉じる</button>
    </header>

    <form method=get target=_blank>
      <table class=config>
        <tr>
          <th><label for=export-lang>Language</label>
          <td>
            <select id=export-lang name=lang>
              <t:for as=$lang x="$tr->avail_langs">
                <option pl:value=$lang pl:label=$lang><!-- XXX label -->
              </t:for>
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

    <hr><!-- XXX -->
    <h1>Import</h1>

    <form action=import method=post enctype=multipart/form-data target=_blank>
      <table class=config>
        <tr>
          <th><label for=import-file>Files</label>
          <td><input type=file name=file multiple id=import-file><!-- XXX accept=... -->

        <tr>
          <th><label for=import-lang>Language</label>
          <td>
            <select id=import-lang name=lang>
              <t:for as=$lang x="$tr->avail_langs">
                <option pl:value=$lang pl:label=$lang><!-- XXX label -->
              </t:for>
            </select>
        <tr>
          <th><label for=import-format>Input format</label>
          <td>
            <select id=import-format name=format>
              <option value=po>PO (GNU Gettext)
            </select>
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

      <p class=buttons><button type=submit>Import</button>
    </form>
    
  </section>
  <script>
    function toggleExportDialog (status) {
      var exportPanel = document.querySelector ('#config-export');
      if (status) {
        var item = document.querySelector ('[itemtype=data]');
        var url = item.querySelector ('[itemprop=export-url]').href;
        exportPanel.querySelector ('form').action = url;

        exportPanel.hidden = false;
      } else {
        exportPanel.hidden = true;
      }
    } // toggleExportDialog

    (function () {
      var f = decodeURIComponent (location.hash.replace (/^#/, ''));
      if (f === 'config-export') {
        toggleExportDialog (true);
      }
    }) ();
  </script>
</div>

<footer class=site>
  <ul>
    <li><a href="/" rel=index>Top</a>
  </ul>
  <ul>
    <li><a href="/help" rel=help>Help</a>
    <li><a href="/api">API</a>
    <li><a href="/rule">Terms</a>
  </ul>
</footer>
