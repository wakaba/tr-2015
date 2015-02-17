<html t:params="$tr $data_params $app">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<header itemscope itemtype=data>
  <hgroup> 
    <h1><code itemprop=url><t:text value="$tr->url"></code></h1>
    <h2><code itemprop=branch><t:text value="$tr->branch"></code></h2>
    <h3><code itemprop=texts-path><t:text value="'/' . $tr->texts_dir"></code></h3>
  </hgroup>

  <link itemprop=data-url pl:href="'data.json?'.$data_params.'&with_comments=1'">
</header>

<table id=texts pl:data-all-langs="join ',', @{$tr->avail_langs}">
  <t:my as=$lang_cell_count x="0+@{$tr->langs}">
  <thead>
    <tr>
      <t:for as=$lang x="$tr->langs">
        <th><t:text value=$lang>
      </t:for>
      <th class=langs-menu-container>
        <button type=button title="言語の選択">&#x25BC;</button>
        <menu hidden>
          <!-- XXX -->
          <t:for as=$lang x="$tr->avail_langs">
            <label><input type=checkbox pl:value=$lang> <t:text value=$lang></label>
          </t:for>
          <hr>
          <a href="#config-langs" onclick=" toggleLangsConfig (true) ">編集...</a>
        </menu>
  <tbody>
    <template>
      <tr class=text-header>
        <th pl:colspan=$lang_cell_count>
          <a class=msgid><code></code></a>
          <a class=text-id><code></code></a>
          <section class=tag-area>
            <h1>タグ</h1>
            <p class=buttons><button type=button class=toggle-edit title="Edit tags">Edit</button>
            <div class=view>
              <p class=tags>...
            </div>
            <form data-action="i/{text_id}/tags" method=post class=edit hidden>
              <p class=tags>...
              <p class=buttons><button type=submit>保存</button>
            </form>
            <p class=status hidden><progress></progress> <span class=message></span>
          </section>

          <section class=args-area>
            <h1>引数</h1>
            <p class=buttons><button type=button class=toggle-edit title="Edit arguments">Edit</button>
            <div class=view>
              <dl class=args></dl>
              <template>
                <dt><code>{<span class=arg-name></span>}</code><dd><span class=arg-desc></span>
              </template>
            </div>
            <form data-action="i/{text_id}/args" method=post class=edit hidden>
              <table class=args>
                <thead>
                  <tr>
                    <th>{変数名}
                    <th>短い説明
                    <th>
                <tbody>
                  <template>
                    <th><code>{<input name=arg_name></span>}</code><td><input name=arg_desc></span><td><button type=button onclick=" if (confirm (getAttribute ('data-confirm'))) this.parentNode.parentNode.parentNode.removeChild (this.parentNode.parentNode) " data-confirm="この引数を削除します">削除</button>
                  </template>
                <tfoot>
                  <tr><th><td><td><button type=button onclick="
                    addArgsEditTableRow (this.parentNode.parentNode.parentNode.parentNode, '', '');
                  ">追加</button>
              </table>
              <p class=buttons><button type=submit>保存</button>
            </form>
            <p class=status hidden><progress></progress> <span class=message></span>
          </section>

          <section class=comments>
            <h1>コメント</h1>
            <div class=comments-container></div>
            <template>
              <article>
                <p class=body>
                <p><time></time>
              </article>
            </template>
            <div class=new-comment>
              <p class=buttons><button type=button class=toggle-edit title="コメントを書く">コメントを書く</button>
              <div class=view>
              </div>
              <form data-action="i/{text_id}/comments" method=post class=edit hidden>
                <p><textarea name=body></textarea>
                <p class=buttons><button type=submit>投稿</button>
              </form>
              <p class=status hidden><progress></progress> <span class=message></span>
            </div>
          </section>
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
            </form>
        </t:for>
    </template>
  <tfoot>
    <tr class=status hidden>
      <td pl:colspan=$lang_cell_count>
        <progress></progress> <span class=message></span>
    <tr>
      <td pl:colspan=$lang_cell_count>

<form action=add method=post onsubmit="
  var form = this;
  form.hidden = true;
  var mainTable = document.getElementById ('texts');
  var mainTableStatus = mainTable.querySelector ('tfoot .status');
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
      } else { // XXX
      }
      mainTableStatus.hidden = true;
      form.hidden = false;
    }
  };
  xhr.send (fd);
  return false;
">
  <p>
    <label><strong>メッセージID</strong>: <input type=text name=msgid pl:value="$app->text_param ('msgid') // ''"></label>
    <t:for as=$tag x="$app->text_param_list ('tag')">
      <input type=hidden name=tag pl:value=$tag>
    </t:for>
    <button type=submit>追加</button>
</form>


</table>

<script src=/js/time.js charset=utf-8></script>
<script>
function addTexts (texts) {
  var mainTable = document.getElementById ('texts');
  var rowContainer = mainTable.querySelector ('tbody');
  var rowTemplate = rowContainer.querySelector ('template');
  for (var textId in texts) (function (text) {
    var fragment = document.createElement ('tbody');
    fragment.innerHTML = rowTemplate.innerHTML;

    var tid = fragment.querySelector ('.text-id');
    tid.href = './?text_id=' + encodeURIComponent (textId);
    tid.querySelector ('code').textContent = textId;

    if (text.msgid) {
      var mid = fragment.querySelector ('.msgid');
      mid.href = './?msgid=' + encodeURIComponent (text.msgid);
      mid.querySelector ('code').textContent = text.msgid;
    }

    Array.prototype.map.call (fragment.querySelectorAll ('.tag-area'), function (area) {
      var toggle = area.querySelector ('button.toggle-edit');
      toggle.onclick = function () {
        toggleAreaEditor (area, !this.classList.contains ('active'));
      };
      area.querySelector ('form.edit').onsubmit = function () {
        toggleAreaEditor (area, false);
        return saveArea (area);
      };

      var form = area.querySelector ('form.edit');
      var tagsContainer = form.querySelector ('.tags');
      tagsContainer.textContent = '';
      if (text.tags) {
        for (t in text.tags) {
          var input = document.createElement ('input');
          input.name = 'tag';
          input.value = text.tags[t];
          tagsContainer.appendChild (input);
          tagsContainer.appendChild (document.createTextNode (' '));
        }
      }
      var button = document.createElement ('button');
      button.type = 'button';
      button.textContent = 'Add';
      button.onclick = function () {
        var p = this.parentNode;
        var input = document.createElement ('input');
        input.name = 'tag';
        p.insertBefore (input, this);
        p.insertBefore (document.createTextNode (' '), this);
      };
      tagsContainer.appendChild (button);
      area.trSync = syncTagAreaView;
      area.trSync (area);
    });

    Array.prototype.map.call (fragment.querySelectorAll ('.args-area'), function (area) {
      var toggle = area.querySelector ('button.toggle-edit');
      toggle.onclick = function () {
        toggleAreaEditor (area, !this.classList.contains ('active'));
      };
      area.querySelector ('form.edit').onsubmit = function () {
        toggleAreaEditor (area, false);
        return saveArea (area);
      };

      var form = area.querySelector ('form.edit');
      var table = form.querySelector ('table.args');
      (text.args || []).forEach (function (arg) {
        var desc = text["args.desc." + arg] || "";
        addArgsEditTableRow (table, arg, desc);
      });
      syncArgsAreaView (area);

      area.trSync = syncArgsAreaView;
      area.trSync (area);
    });

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

    var comments = fragment.querySelector ('.comments');
    comments.querySelector ('button.toggle-edit').onclick = function () {
      toggleAreaEditor (comments, true);
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
            el.action = el.getAttribute ('data-action').replace (/\{text_id\}/g, textId);
          });
          
          Array.prototype.slice.call (fragment.children).forEach (function (el) {
            rowContainer.appendChild (el);
          });
  }) (texts[textId]);
} // addTexts

  var mainTable = document.getElementById ('texts');
  var mainTableStatus = mainTable.querySelector ('tfoot .status');
  mainTableStatus.hidden = false;
  mainTableStatus.querySelector ('.message').textContent = 'Loading...';

  var item = document.querySelector ('[itemtype=data]');
  var url = item.querySelector ('[itemprop=data-url]').href;
  var xhr = new XMLHttpRequest;
  xhr.open ('GET', url, true);
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      if (xhr.status < 400) {
        var json = JSON.parse (xhr.responseText);
        addTexts (json.texts);
        mainTableStatus.hidden = true;
      } else {
        // XXX
      }
    }
  };
  xhr.send (null);

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

function syncTagAreaView (area) {
  var edit = area.querySelector ('form.edit');
  var view = area.querySelector ('.view');

  var editTags = edit.querySelector ('.tags');
  var viewTags = view.querySelector ('.tags');
  viewTags.textContent = '';
  Array.prototype.forEach.call (editTags.querySelectorAll ('input[name=tag]'), function (input) {
    var tag = input.value;
    var a = document.createElement ('a');
    a.href = './?tag=' + encodeURIComponent (tag);
    a.textContent = tag;
    viewTags.appendChild (a);
    viewTags.appendChild (document.createTextNode (' '));
  });
} // syncTagAreaView

function syncArgsAreaView (area) {
  var edit = area.querySelector ('form.edit');
  var view = area.querySelector ('.view');

  var editArgs = edit.querySelector ('.args').tBodies[0];
  var viewArgs = view.querySelector ('.args');
  viewArgs.textContent = '';
  var template = view.querySelector ('template');

  Array.prototype.forEach.call (editArgs.rows, function (tr) {
    var div = document.createElement ('div');
    div.innerHTML = template.innerHTML;
    var name = tr.querySelector ('input[name=arg_name]').value;
    if (!name) return;
    div.querySelector ('.arg-name').textContent = name;
    div.querySelector ('.arg-desc').textContent = tr.querySelector ('input[name=arg_desc]').value;
    Array.prototype.slice.call (div.childNodes).forEach (function (node) {
      viewArgs.appendChild (node);
    });
  });
} // syncArgsAreaView

function addArgsEditTableRow (table, name, desc) {
  var template = table.querySelector ('tbody template');
  var tr = document.createElement ('tr');
  tr.innerHTML = template.innerHTML;
  tr.querySelector ('input[name=arg_name]').value = name;
  tr.querySelector ('input[name=arg_desc]').value = desc;
  table.tBodies[0].appendChild (tr);
} // addArgsEditTableRow

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
  toggle.classList.toggle ('active', editMode);
} // toggleAreaEditor

function saveArea (area) {
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
        area.trSync (area);
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

<div class=dialog id=config-langs hidden>
  <section>
    <h1>言語設定</h1>

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

      <p class=buttons>
        <button type=button class=save>保存して閉じる</button>
        <button type=button class=close>閉じる</button>
    </form>
    <p class=status hidden><progress></progress> <span class=message></span>
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
        var langsMenuButton = langsMenuContainer.querySelector ('button');
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
  </section>
</div>
