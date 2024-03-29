# ftd_lua_examples
FromTheDepthes用 LUAビルドツール及び、同ツールを用いたLUA制御ビークルの例

以下の内容を含みます
* サンプルのブループリント（XF_30_Gannet2.blueprint）
* サンプルのLUAコード
* LUAコードのビルドツール

FromTheDepthesのバージョンは v2.3.1.15 を想定しています。今後ゲームのバージョンアップに合わせて更新します。
v2.4.2.5でも問題なし。

## サンプルのブループリント

ビークルの作成作業や個人の作成したビークル毎の特性の違いに煩わされないよう、サンプル機体としてゲーム内の既存航空機「XF-30」を選択しました。
同機の機体後方にLUABoxを取り付け、本サンプルのコードを設定した機体のブループリントを
<pre>
XF_30_Gannet2.blueprint
</pre>
としてプロジェクトディレクトリ直下に配置しました。
バルーンでの離陸後（ON/OFF制御なので）フラフラしつつも、リソースゾーン付近と、そこから北へ2キロ付近の2地点間を往復するはずです。

もしくはゲーム内で、XF-30 をロードし、機体後方（空気抵抗を受けない箇所）にLUABoxを配置した上で、
<pre>
./dest/Airplane-XF30.lua
</pre>
の内容を貼り付けても同じ結果が得られます(NPCビークルの上書きに注意。別名で保存しましょう)


## サンプルのLUAコードの内容

LUA制御ビークルの最初の1歩として必要性が高いと思われる
**「ビークルを任意の地点へ移動させる」** 
処理についてフォーカスした最小構成のサンプルです。
前述のように、リソースゾーン付近とそこから北へ2キロ付近の2地点間を往復します。

後述のビルドツールによるファイルの結合を前提としている為、機能毎にファイルが分割され、実装は主に以下のディレクトリ内に配置されています。
<pre>
./src/sample/
</pre>

### ざっくり説明

実装を参考にしたい場合に、要求の多そうな項目についてどのファイルを確認すれば良いのかを以下に記します。

#### エレベーターやエルロンやラダーをどちら側に動かせば良いのかの判別方法

以下の実装で行っています。
<pre>
./src/sample/lib/pilot_guidance.lua
</pre>

その上で、以下の実装で実際に操縦を行います。
<pre>
./src/sample/pilot/turn_strategies/roll_base_turn.lua
</pre>

角度の計算とか（直接的には）一切行っていません。数学できないマンでも全然大丈夫。


#### 処理の全体の流れ

以下のファイルを参照すると大体把握できるかと思います。
<pre>
./src/main/airplane/Airplane.lua
./src/sample/universal_behavior.lua
./src/sample/phase/takeoff.lua
./src/sample/phase/cruise.lua
</pre>

#### その他

* LUABoxでの処理の起点である、Update(I) は1秒間に40回呼び出されます。中の人はこれを1秒間に40回手番（ターン）が回ってくるシミュレーションゲームと考える事にしています。
* Update(I)について、応答の時間制限等は無いようですが、あまり時間の掛る処理を行うとゲーム全体の速度がスローダウンします。同じ処理を同一ターン内で繰り返さない、重い処理は毎ターン実行せず一定ターンおきに間欠的に実行する等のアイデアが使えます。
* どのような処理が重いのかはUnity関連のサイトを見ると参考になります。
* リファレンス等に明示されていないようですが、 I:Get～ 系メソッドで取得する大半のオブジェクト（TargetInfo等）の生存期間は1ターンのようです。
* 例えば位置情報の場合、I:Get～ 系メソッドから取得したオブジェクトの .Position等で参照可能なVector3を保持しておく事で、ターンを跨いで数秒前との位置の差分を取る等が可能です。
* WEBアプリのように基本的にはステートレスだと考えると分かり易いかも。その上で（これもWEBアプリのセッション等のように）ターンを跨いで情報を保持する場合は、更新や解放のタイミング等について考慮が必要な場合もあります。
* TargetPositionInfoのAzimuthやElevationは便利なようで航空機だと微妙に不便。垂直方向の機動や背面飛行を考慮しなくても良い艦船や飛行艦なら普通に便利だと思う。


本プロジェクトはサンプルなので最低限の制御としていますが、ここから

* 地形、他ビークル、ミサイル等の各種回避行動
* 火器管制
* 移動目標の先読み
* PID制御

等々を追加する事で実用的なビークルとなります。

***

## ビルドツールについての説明
ゲームの仕様上、LUABoxへ貼り付けるLUAコードを1ファイルに記載する必要がありますが、コードが長くなると保守性や再利用性の面でかなり厳しいものがあります。
そこで、Java等のように1ファイル1クラスの単位でコーディングし、その後ファイルを結合してLUABox貼り付け用のLUAコードを生成するツールを作成しました。


### 導入方法

python3 を想定しています。また以下のライブラリに依存します。pipで適宜インストールしてください。
<pre>
jinja2
pyperclip
</pre>

### 実行方法

以下のように build.py を実行すると、dest ディレクトリにLUABox貼り付け用の成果物が出力されます。
~~~
python build.py
~~~

また、以下のように、environmentsディレクトリ（後述）内のビークル名を指定する事で、そのビークル用のビルド後のLUAコードがクリップボードにコピーされます。
~~~
python build.py XF30
~~~


### ファイルの配置についての説明

<pre>
├─dest LUABox貼り付け用のファイル出力先
├─main
│  ├─{ビークル種別1}
│  │  └─environments 個々のビークル毎の環境設定ファイルを配置
│  └─{ビークル種別2}
│      └─environments 個々のビークル毎の環境設定ファイルを配置
└─src 実装用のluaファイルを配置。サブディレクトリ内への配置も可能
</pre>


本サンプルでは以下の配置となっています。

<pre>
├─main
│  ├─airplane
│  │  │  Airplane.lua （航空機用のメインファイル）
│  │  │  
│  │  └─environments
│  │          XF30.lua （XF30用の環境定義ファイル）
│  │          
│  └─ship
│      │  Ship.lua （艦船用のメインファイル）
│      │  
│      └─environments
└─src
    └─sample （サンプルの実装を格納）

</pre>

#### main ディレクトリ
FtDのLUABoxにおけるプログラムの起点である Update(I) 関数を記載するファイルを配置します。
ビークルの大まかな種別（艦船、航空機等）毎にファイルを作成する前提です。
同ファイル内でインポートするファイルを変える事で、ビークル種別毎の実装を大きく変える事が出来ます。

ディレクトリ名とファイル名は自由に決定してください。
このファイル名とenvironmentsディレクトリ内での環境定義ファイルにより、
ビルド後の成果物は ./dest 以下のファイル名で出力されます。
<pre>
{mainファイル名}-{（environmentsでの）ビークル名}.lua 
</pre>

mainファイル名がAirplane.lua、environmentsディレクトリでの環境定義ファイル名が XF30.lua の場合の例
<pre>
Airplane-XF30.lua
</pre>

environmentsディレクトリ内に複数の定義ファイルが存在する場合は、ファイルの数分、それぞれに対応した成果物が出力されます。

実際のファイルの記載方法については後述しますが、まずはサンプルとして配置した以下のファイルを確認すると概ね想像が付くと思います。
<pre>
./main/airplane/Airplane.lua
</pre>


#### main/environments ディレクトリ
プログラム内で参照するビークル毎の設定情報を記載します。
設定情報とは例えば、個々のビークル毎に最適な値が異なりプログラム内にはハードコーディングしたく無いであろう、最適交戦距離や最低/最大高度 等々です。

こちらもサンプルとして以下のファイルを配置しました。
<pre>
./main/airplane/environments/XF30.lua
</pre>

#### src ディレクトリ
メインファイルより呼び出される実装を記載します。
ここに配置したファイルをメインファイル側で任意にインポートする想定です。

基本的にクラス単位でファイルを配置する前提です。自由にサブディレクトリを作成してファイルを配置して構いません。
但し、現状では全てのファイル名がユニークである必要があります。


### ファイルのインポートについて

メインファイル内で以下のようにプレースホルダを記載する事で、srcディレクトリ内のファイルをインポート可能です。
~~~
--{{ファイル名（拡張子なし）}}
~~~

上記記載部分が単純に指定ファイルの内容に置き換わり、指定ファイルの実装が別のファイルから使用可能になります。

例えば、./src/lib/self_awareness.lua ファイルをインポートするには以下のように記載します。
~~~
--{{self_awareness}}
~~~

./src ディレクトリ内のソースファイル内でも、プレースホルダによるインポートは可能ですが、以下の条件があります。

* ソースファイル内でインポート可能なファイルは、プレースホルダを記載したファイルが存在するディレクトリのサブディレクトリ内のものに限定される。


また、メインファイル内の以下の記載部分に environments ディレクトリ下のビークル毎の環境定義ファイルの内容がインポートされます。
~~~
--{{ENVIRONMENT}}
~~~
通常はファイルの先頭に記載するのが良いと思います。

### デバッグ等について

ゲーム内でのエラー時にLUABoxに表示される行番号が、srcディレクトリ内のソースファイルではなく、destディレクトリに出力されたビルド後のファイルの行番号となります。
ビルド後のファイルには、以下のようにその部分のファイル名が出力されますので、凡その見当は付くかと思います。
<pre>
--==== START self_awareness.lua ====--

（self_awareness.luaのコード）

--==== END self_awareness.lua ====--
</pre>

また、シンタックスエラーについては、LUAがインストールされたPCであれば、以下のように luac コマンドを使う事で事前にチェック可能です。
<pre>
\lua\luac53.exe .\dest\*.lua
</pre>
