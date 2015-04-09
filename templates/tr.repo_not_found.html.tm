<html t:params="$tr $app">
<t:call x="use Wanage::URL">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>
<body>

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a pl:href="'/tr/'.(percent_encode_c $tr->url).'/'"><code itemprop=url><t:text value="$tr->url"></code></a></h1>
    </hgroup>
  </header>

  <section>
    <h1>リポジトリーが見つかりません</h1>

    <p>指定されたリポジトリーは存在しないか、アクセスする権限がありません。

    <section>
      <h1>非公開リポジトリーの場合</h1>

      <p class=guest-only>非公開リポジトリーにアクセスするには、
      まず<a href=XXX>ログイン</a>してください。

      <div class=non-guest-only>
        <dl class=switch>
        <dt>あなたがこのリポジトリーの管理者の場合
        <dd>
          <p>参加すると、このリポジトリーを編集できるようになります。
          <form action=./acl.json method=post><!-- XXX path -->
            <input type=hidden name=operation value=join>
            <button type=submit>開発者として参加</button>
          </form><!-- XXX ajax -->
        
      <div class=XXX>
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


        <dt>あなたがこのリポジトリーの管理者でない場合
        <dd>
          <p>リポジトリーの管理者に、編集権限の設定画面からあなたのアカウントのアクセスを承認するよう依頼してください。
        </dl>
      </div>
    </section>
  </section>
</section>

<t:include path=_footer.html.tm m:app=$app />
