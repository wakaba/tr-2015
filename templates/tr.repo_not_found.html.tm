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
          <p>「所有権の取得」すると、このリポジトリーを編集できるようになります。
        
          <form action=acl method=post><!-- XXX path -->
            <input type=hidden name=operation value=get_ownership>
            <button type=submit>所有権を取得</button>
          </form><!-- XXX ajax -->

        <dt>あなたがこのリポジトリーの管理者でない場合
        <dd>
          <p>リポジトリーの管理者に、編集権限の設定画面からあなたのアカウントのアクセスを承認するよう依頼してください。
        </dl>
      </div>
    </section>
  </section>
</section>

<t:include path=_footer.html.tm />
