// Creazione iniziale dei modelli. Per i ritocchi modificare i JSON e usare sync-fallback.mjs.
import fs from 'node:fs';
import path from 'node:path';
const out = 'src/gui';
const rgb = (r,g,b) => ({Color3:[r/255,g/255,b/255]});
const dim = (x,y) => ({UDim2:[[x,0],[y,0]]});
const vec = (x,y) => ({Vector2:[x,y]});
const navy=rgb(16,20,28), slate=rgb(28,34,48), gold=rgb(255,196,80), white=rgb(240,240,242);
const node=(name,className,properties={},children=[])=>({name,className,properties,children});
const attr = o => Object.fromEntries(Object.entries(o).map(([k,v])=>[k,{[typeof v==='boolean'?'Bool':'String']:v}]));
const corners=()=>[node('Corner','UICorner',{CornerRadius:{UDim:[0,10]}}),node('Stroke','UIStroke',{Color:gold,Thickness:1,Transparency:.65})];
const f=(name,x,y,w,h,children=[],props={})=>node(name,'Frame',{Position:dim(x,y),Size:dim(w,h),BorderSizePixel:0,BackgroundColor3:slate,BackgroundTransparency:1,...props},children);
const limit=(minx,miny,maxx=10000,maxy=10000)=>node('SizeLimit','UISizeConstraint',{MinSize:vec(minx,miny),MaxSize:vec(maxx,maxy)});
const text=(name,value,x,y,w,h,sz=15,props={})=>node(name,'TextLabel',{Position:dim(x,y),Size:dim(w,h),BackgroundTransparency:1,Text:value,Font:'GothamBold',TextSize:sz,TextColor3:white,TextWrapped:true,RichText:true,TextStrokeTransparency:.6,TextXAlignment:'Left',...props});
const image=(name,asset,x,y,w,h)=>node(name,'ImageLabel',{Position:dim(x,y),Size:dim(w,h),BackgroundTransparency:1,Image:'',ScaleType:'Fit',Attributes:attr({UiAsset:asset})});
const button=(name,label,x,y,w,h,asset='btn_secondary_normal')=>node(name,'TextButton',{Position:dim(x,y),Size:dim(w,h),BackgroundColor3:slate,BorderSizePixel:0,Text:label,Font:'GothamBold',TextSize:14,TextColor3:white,TextWrapped:true,TextStrokeTransparency:.6,AutoButtonColor:true,Attributes:attr({UiAsset:asset})},[...corners(),limit(44,44)]);
const panel=(name,x,y,w,h,children=[],asset='panel_card',props={})=>f(name,x,y,w,h,[...corners(),...children],{BackgroundTransparency:.08,Attributes:attr({UiAsset:asset}),...props});
const listLayout=()=>node('Layout','UIListLayout',{Padding:{UDim:[0,8]},SortOrder:'LayoutOrder'});
const scroll=(name,x,y,w,h,children=[])=>node(name,'ScrollingFrame',{Position:dim(x,y),Size:dim(w,h),BackgroundTransparency:1,BorderSizePixel:0,ScrollBarThickness:5,CanvasSize:dim(0,0),AutomaticCanvasSize:'Y',ScrollingDirection:'Y'},[listLayout(),...children]);
const bar=(name,x,y,w,h,color=rgb(110,200,255))=>panel(name,x,y,w,h,[f('Fill',0,0,1,1,[],{BackgroundTransparency:0,BackgroundColor3:color}),text('Text','',0,0,1,1,12,{TextXAlignment:'Center',ZIndex:3})],'');
const screen=(name,children,order=5,enabled=true,inset=false)=>node(name,'ScreenGui',{ResetOnSpawn:false,IgnoreGuiInset:inset,ZIndexBehavior:'Sibling',DisplayOrder:order,Enabled:enabled,Attributes:attr({ResponsiveUI:true})},children);
const tabs=['Store','Backpack','Dragons','Crafting','Upgrades'];
const tabContent=name=>f(name,0,0,1,1,[],{Visible:false});
const store=tabContent('Store'); store.children=[f('Tabs',0,0,1,.18,['Buy','Sell','Robux'].map((s,i)=>button(s,s,i/3,0,.31,1))),scroll('List',0,.21,1,.79)];
const backpack=tabContent('Backpack');backpack.children=[scroll('List',0,0,1,1)];
const dragons=tabContent('Dragons');dragons.children=[text('Header','Your dragons and hatching nest',0,0,1,.12,13),f('Body',0,.14,1,.86,[f('Nest',0,0,.36,1,[text('Title','Hatching nest',0,0,1,.1),scroll('List',0,.12,1,.88)]),f('Dragons',.38,0,.62,1,[text('Title','Your dragons',0,0,1,.1),scroll('List',0,.12,1,.88)])])];
const crafting=tabContent('Crafting');crafting.children=[scroll('List',0,0,1,1)];
const upgrades=tabContent('Upgrades');upgrades.children=[f('Tabs',0,0,1,.18,['Upgrades','Bounties','Rebirth'].map((s,i)=>button(s,s,i/3,0,.31,1))),scroll('List',0,.21,1,.79)];
const row=(name,height,children)=>panel(name,0,0,.98,.5,[limit(0,height,10000,height),...children]);
const templates=node('Templates','Folder',{},[
 row('ItemCard',164,[image('Icon','icon_egg',.03,.04,.22,.44),text('Title','Item',.28,.04,.68,.16),text('Description','',.28,.21,.68,.27,12),text('Cost','',.05,.5,.9,.15,13),button('Buy','Buy',.03,.7,.94,.28,'btn_primary_normal'),f('SellActions',.03,.7,.94,.28,[button('One','Sell 1',0,0,.48,1),button('All','Sell all',.52,0,.48,1)])]),
 row('InventoryCard',142,[image('Icon','icon_egg',.04,.05,.92,.6),text('Title','Item',.04,.65,.92,.2,13),text('Count','0',.65,.85,.31,.13,13,{TextXAlignment:'Right'})]),
 row('RecipeCard',240,[f('Preview',.03,.03,.22,.28),text('Title','Recipe',.28,.03,.68,.12),text('Description','',.28,.16,.68,.16,12),f('Materials',.03,.36,.94,.34),button('Craft','Craft',.03,.77,.94,.2,'btn_primary_normal')]),
 row('Material',48,[image('Icon','ore_Ferro',0,0,.15,1),text('Text','',.18,0,.82,1,12)]),
 row('EggCard',180,[image('Icon','icon_egg',.02,.03,.3,.35),text('Title','Egg',.35,.03,.6,.32,13),text('Time','',.04,.42,.92,.2,13),button('Hatch','Hatch!',.04,.7,.92,.27,'btn_primary_normal')]),
 row('DragonCard',248,[f('Preview',.03,.03,.25,.36),image('Element','elem_Gelo',.02,.39,.15,.15),text('Title','Dragon',.3,.03,.66,.19,14),text('Ability','',.3,.23,.66,.18,12),bar('XP',.2,.46,.76,.09),button('Follow','Follow',.03,.6,.45,.19,'btn_primary_normal'),button('Evolve','Evolve',.52,.6,.45,.19,'btn_primary_normal'),button('Sell','Sell',.03,.81,.94,.18,'btn_danger_normal')]),
 row('UpgradeCard',240,[text('Icon','',.02,.03,.2,.22,30),text('Title','Upgrade',.24,.03,.72,.15),text('Description','',.24,.2,.72,.18,12),text('Effect','',.04,.42,.92,.12,12),text('Cost','',.04,.56,.92,.2,12),button('Action','Upgrade',.03,.78,.94,.2,'btn_primary_normal')]),
 row('BountyCard',170,[text('Title','Bounty',.04,.03,.92,.18),bar('Progress',.04,.25,.92,.09),text('Reward','',.04,.38,.92,.24,12),button('Claim','Claim',.04,.7,.92,.28,'btn_primary_normal')]),
 row('RebirthCard',300,[text('Title','Rebirth',.04,.02,.92,.1,20),text('Description','',.04,.14,.92,.42,13),text('Cost','',.04,.59,.92,.2,13),button('Action','Rebirth',.04,.82,.92,.16,'btn_danger_normal')]),
 row('TextCard',100,[text('Text','',.04,.04,.92,.92,13)]),
 text('Heading','',0,0,.98,.12,15),
]);
templates.children.at(-1).children=[limit(0,36,10000,36)];
const main=screen('MainMenu',[
 f('Column',.01,.3,.09,.4,[...tabs.map((s,i)=>{const b=button(s,s,0,i*.145,1,.135); b.children.push(image('Icon',{Store:'icon_shop',Backpack:'icon_backpack',Dragons:'icon_dragons',Crafting:'icon_crafting',Upgrades:'icon_settings'}[s],.02,.12,.2,.76));return b;}),button('Teleport','Teleport',0,.725,1,.135),button('NascondiIcone','Hide',0,.87,1,.13)]),
 panel('Window',.15,.08,.78,.84,[limit(300,260,880,720),image('Background','bg_menu',0,0,1,1),text('Title','Climbing & Dragons',.05,.02,.77,.09,22),button('Close','X',.88,.02,.08,.09,'btn_close'),f('Content',.045,.15,.91,.76,[store,backpack,dragons,crafting,upgrades]),text('Status','',.05,.92,.9,.06,13,{TextXAlignment:'Center'})],'panel_main',{Visible:false}),templates
],5);
const hud=screen('ClimbHUD',[
 panel('Player',.015,.015,.25,.18,[text('Name','Climber',.12,.04,.84,.16,13),image('HealthIcon','icon_health',.01,.25,.1,.2),bar('Health',.12,.25,.84,.2,rgb(220,60,60)),image('StaminaIcon','icon_stamina',.01,.5,.1,.17),bar('Stamina',.12,.5,.84,.17,rgb(120,200,110)),bar('Shield',.12,.74,.84,.14)]),
 panel('Coins',.015,.2,.25,.07,[image('Icon','icon_coin',.02,.05,.12,.9),text('Text','0',.16,0,.35,1),image('PitonIcon','icon_piton',.52,.05,.12,.9),text('Pitons','0',.66,0,.32,1)]),
 panel('Weather',.765,.015,.22,.23,[image('Icon','weather_clear',.02,.04,.24,.25),text('Fallback','Clear',.02,.04,.24,.25,13),text('Time','12:00',.3,.03,.66,.17,22),text('Clock','',.3,.21,.66,.12,11),text('Altitude','0 m',.06,.37,.88,.13,14),bar('Warmth',.06,.54,.88,.12,rgb(255,150,70)),text('Finder','',.05,.7,.9,.15,11),text('Gear','',.05,.86,.9,.12,10)]),
 panel('Pet',.12,.3,.24,.18,[image('Element','elem_Gelo',.02,.04,.18,.22),text('Name','Dragon',.22,.03,.74,.2,13),text('Level','',.05,.28,.9,.17,12),bar('XP',.05,.52,.9,.17),text('Stats','',.05,.75,.9,.2,11)]),
 panel('Quest',.3,.015,.44,.23,[image('Icon','icon_quest',.02,.04,.1,.2),text('Title','Mission',.14,.03,.8,.18,14),text('Text','',.05,.23,.9,.35,13),button('Skip','Skip tutorial',.48,.65,.46,.32,'btn_primary_normal')],'panel_quest',{Visible:false}),
 panel('Notice',.28,.26,.46,.09,[text('Text','',.05,.05,.9,.9,14,{TextXAlignment:'Center'})],'panel_toast',{Visible:false}),
 text('Hint','',.25,.79,.5,.06,14,{TextXAlignment:'Center'})
],1);
const death=screen('DeathScreen',[f('Shade',0,0,1,1,[],{BackgroundColor3:rgb(0,0,0),BackgroundTransparency:.45}),image('Background','bg_death',0,0,1,1),f('Panel',.1,.1,.8,.8,[text('Title','YOU FELL',0,.03,1,.2,48,{Font:'GothamBlack',TextXAlignment:'Center',TextColor3:rgb(255,80,70)}),text('Cause','',0,.26,1,.12,22,{TextXAlignment:'Center'}),text('Stats','',0,.42,1,.1,15,{TextXAlignment:'Center'}),text('Tip','',0,.55,1,.15,14,{TextXAlignment:'Center'}),button('Respawn','Respawn',.02,.79,.46,.19,'btn_primary_normal'),button('Revive','Revive (Robux)',.52,.79,.46,.19)])],50,false,true);
const teleport=screen('Teletrasporto',[button('Open','Teleport (T)',.84,.4,.15,.1),panel('Panel',.2,.14,.65,.68,[text('Title','Teleport',.05,.02,.75,.12,22),button('Close','X',.85,.02,.1,.12,'btn_close'),...['Base camp (hub)','My camp','Dragon training','Muscle Beach (gym)'].map((n,i)=>{const b=button('Destination'+(i+1),n,.05,.18+i*.2,.9,.18);b.children.push(image('Icon','icon_teleport',.01,.1,.1,.8),text('Distance','',.72,.1,.25,.8,12,{TextXAlignment:'Right'}));return b;})],'panel_main',{Visible:false})],7);
const mobile=screen('MobileControls',[f('Actions',.69,.32,.3,.3,['Run','JumpOff','Piton','Release','Climb','Grapple','Throw','Mine','Shoot'].map((n,i)=>{const b=button(n,n,(i%3)*.33,Math.floor(i/3)*.33,.3,.3,'btn_round_normal');b.properties.Visible=false;b.children.push(node('Aspect','UIAspectRatioConstraint',{AspectRatio:1}),image('Icon','act_'+({Run:'sprint',JumpOff:'jump',Release:'piton'}[n]||n.toLowerCase()),.18,.1,.64,.58));return b;}))],8,false);
const combat=screen('CombatHUD',[button('Speciale','',.8,.54,.08,.15,'btn_round_normal'),text('Timer','',.36,.38,.38,.055,18,{TextXAlignment:'Center'}),text('Event','',.36,.44,.38,.05,13,{TextXAlignment:'Center'})],3);
combat.children[0].children.push(node('Aspect','UIAspectRatioConstraint',{AspectRatio:1}),image('Icon','act_shoot',.15,.05,.7,.65),text('Key','Z',0,.72,1,.25,12,{TextXAlignment:'Center'}),text('Cooldown','',0,0,1,1,20,{TextXAlignment:'Center',BackgroundColor3:navy,BackgroundTransparency:.35,ZIndex:5,Visible:false}));
const loading=screen('Caricamento',[panel('Background',0,0,1,1,[], 'bg_loading'),image('Logo','logo',.15,.08,.7,.35),text('Title','Climbing & Dragons',.1,.15,.8,.16,40,{Font:'GothamBlack',TextXAlignment:'Center'}),bar('Progress',.18,.69,.64,.035,gold),text('Tip','Place a piton before the hard part.',.1,.76,.8,.07,16,{TextXAlignment:'Center'}),button('Play','PLAY',.35,.86,.3,.08,'btn_primary_normal')],1000,false,true);
loading.children.at(-1).properties.Visible=false;
for(const s of [main,hud,death,teleport,mobile,combat,loading]){
 fs.mkdirSync(path.join(out,s.name),{recursive:true});
 fs.writeFileSync(path.join(out,s.name,'init.meta.json'),JSON.stringify({className:'ScreenGui',properties:s.properties},null,2)+'\n');
 for(const c of s.children)fs.writeFileSync(path.join(out,s.name,c.name+'.model.json'),JSON.stringify(c,null,2)+'\n');
}
