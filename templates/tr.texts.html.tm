<html t:params="$tr $data_params $app">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>

<!-- XXX onbeforeunload -->

<header itemscope itemtype=data>
  <hgroup> 
    <h1><code itemprop=url><t:text value="$tr->url"></code></h1>
    <h2><code itemprop=branch><t:text value="$tr->branch"></code></h2>
    <h3><code itemprop=texts-path><t:text value="'/' . $tr->texts_dir"></code></h3>
  </hgroup>

  <link itemprop=data-url pl:href="'data.json?'.$data_params.'&with_comments=1'">
</header>

<table id=texts>
  <t:my as=$lang_cell_count x="0+@{$tr->langs}">
  <thead>
    <tr>
      <t:for as=$lang x="$tr->langs">
        <th><t:text value=$lang>
      </t:for>
  <tbody>
    <template>
      <tr class=text-header>
        <th pl:colspan=$lang_cell_count>
          <a class=msgid><code></code></a>
          <a class=text-id><code></code></a>
          <div class=tag-area>
            <div class=view>
              <p class=buttons><button type=button class=toggle-edit>Edit</button>
              <p class=tags>...
            </div>
            <form data-action="i/{text_id}/tags" method=post class=edit hidden>
              <p class=tags>...
              <p class=buttons><button type=submit>保存</button>
            </form>
            <p class=status hidden><progress></progress> <span class=message></span>
          </div>
      <tr class=text-annotations>
        <td pl:colspan=$lang_cell_count>
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
              <div class=view>
                <p class=buttons><button type=button class=toggle-edit>コメントを書く</button>
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
            <div class=view>
              <p class=buttons><button type=button class=toggle-edit>Edit</button>
              <p class=body_o>
            </div>
            <form data-action="i/{text_id}/" method=post class=edit hidden>
              <input type=hidden name=lang pl:value=$lang>
              <!-- XXX hash -->
              <p><textarea name=body_o required></textarea>
              <p class=buttons><button type=submit>保存</button>
            </form>
            <p class=status hidden><progress></progress> <span class=message></span>
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
      area.querySelector ('button.toggle-edit').onclick = function () {
        toggleAreaEditor (area, true);
      };
      area.querySelector ('form.edit').onsubmit = function () { return saveArea (area) };

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

    Array.prototype.map.call (fragment.querySelectorAll ('.lang-area[data-lang]'), function (area) {
      area.querySelector ('button.toggle-edit').onclick = function () {
        toggleAreaEditor (area, true);
      };
      area.querySelector ('form.edit').onsubmit = function () { return saveArea (area) };
      area.trSync = syncLangAreaView;

      var lang = area.getAttribute ('data-lang');
      var langData = text.langs ? text.langs[lang] : null;
      if (langData) {
        var form = area.querySelector ('form.edit');
        if (langData.body_o) {
          form.querySelector ('[name=body_o]').value = langData.body_o;
        }
        area.trSync (area);
      }
    });

    var comments = fragment.querySelector ('.comments');
    comments.querySelector ('button.toggle-edit').onclick = function () {
      toggleAreaEditor (comments, true);
    };
    var commentForm = comments.querySelector ('form');
    commentForm.onsubmit = function () { return saveArea (comments) };
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
  view.querySelector ('.body_o').textContent = edit.querySelector ('[name=body_o]').value;
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
  if (editMode) {
    edit.hidden = false;
    view.hidden = true;
  } else {
    view.hidden = false;
    edit.hidden = true;
  }
} // toggleAreaEditor

function saveArea (area) {
  var formStatus = area.querySelector ('.status');
  formStatus.hidden = false;
  formStatus.querySelector ('.message').textContent = 'Saving...';
  toggleAreaEditor (area, false);
  var editButton = area.querySelector ('button.toggle-edit');
  editButton.disabled = true;

  var form = area.querySelector ('form.edit');
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
      editButton.disabled = false;
    }
  };
  xhr.send (fd);
  return false;
} // saveArea
</script>
