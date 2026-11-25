# Presentation-only rendering of verified PR #5 summaries. No fitting or scoring.
root<-"outputs/P4/ExternalSD_6416";out<-"figures/P4/presentation"
dir.create(out,recursive=TRUE,showWarnings=FALSE)
a<-read.csv(file.path(root,"matched_baseline/balanced_latent_summary.csv"))
b<-read.csv(file.path(root,"external_sd/balanced_latent_summary.csv"))
ids<-read.csv(file.path(root,"train_game_ids.csv"))$id
stopifnot(nrow(a)==6416,identical(a$id,ids),identical(a$id,b$id),identical(a$n,b$n),identical(a$raw,b$raw),
 max(abs(a$adjustment-(a$mean-a$raw)))<1e-12,max(abs(b$adjustment-(b$mean-b$raw)))<1e-12)
band<-cut(a$n,c(29,40,99,200,999,5000,Inf),labels=c("30-40","41-99","100-200","201-999","1,000-5,000",">5,000"))
summary<-do.call(rbind,lapply(levels(band),function(g) {
 ix<-which(band==g)
 do.call(rbind,lapply(1:2,function(k) {
  z<-abs(if(k==1)a$adjustment[ix] else b$adjustment[ix]);q<-quantile(z,c(.25,.5,.75),names=FALSE)
  data.frame(band=g,games=length(ix),x=median(a$n[ix]),model=c("M1b baseline","M1b-ExternalSD")[k],q25=q[1],median=q[2],q75=q[3])
 }))
}))
old<-read.csv(file.path(root,"comparison/grouped_shrinkage.csv"))
stopifnot(sum(summary$games)/2==6416,
 abs(summary$median[1]-old$baseline_median_abs_adjustment[old$group=="n30_40"])<1e-12,
 abs(summary$median[2]-old$external_median_abs_adjustment[old$group=="n30_40"])<1e-12,
 round(summary$median[1],4)==.2135,round(summary$median[2],4)==.0710)
d<-read.csv(file.path(root,"comparison/designer_effects.csv"),fileEncoding="UTF-8")
# Deterministic selection by game count; alphabetic name resolves ties.
d<-d[order(-d$training_games,enc2utf8(d$designer),method="radix"),][1:14,]
stopifnot(nrow(d)==14,min(d$training_games)>=21,!anyDuplicated(d$designer),
 all(d$lower95_baseline<=d$mean_baseline&d$mean_baseline<=d$upper95_baseline),
 all(d$lower95_external<=d$mean_external&d$mean_external<=d$upper95_external),
 all(d$pass_baseline),all(d$pass_external))
write.csv(summary,file.path(out,"shrinkage_plot_data.csv"),row.names=FALSE)
write.csv(d,file.path(out,"designer_plot_data.csv"),row.names=FALSE,fileEncoding="UTF-8")
# Mirror P6's published 00_theme.R palette without its ggplot2 dependency.
blue<-"#2a78d6";orange<-"#eb6834";ink<-"#1a1a19";secondary<-"#52514e";grid<-"#e5e4e0";surface<-"#fcfcfb"
canvas<-function(title,subtitle,caption1,caption2) {
 par(mar=c(0,0,0,0),family="sans",ps=20,fg=ink,col.axis=secondary,col.lab=secondary)
 plot.new();plot.window(c(0,1),c(0,1),xaxs="i",yaxs="i")
 text(.055,.945,title,adj=0,cex=1.43,font=2)
 text(.055,.892,subtitle,adj=0,cex=.94,col=secondary)
 legend(.055,.858,legend=c("M1b baseline","M1b-ExternalSD"),col=c(blue,orange),
  pch=c(16,18),lwd=2.5,horiz=TRUE,bty="n",cex=.95,x.intersp=.8,y.intersp=.8)
 text(.055,.074,caption1,adj=0,cex=.83,col=secondary)
 text(.055,.036,caption2,adj=0,cex=.83,col=secondary)
}
fig1<-function() {
 canvas("Fewer ratings, larger score adjustments",
  "Same 6,416 development games | Median absolute adjustment by rating-count band",
  "Bars: interquartile range across games, not posterior credible intervals. Band sizes are shown below the axis.",
  "Training results only. Smaller adjustments under ExternalSD do not establish better predictive performance.")
 par(fig=c(.055,.965,.20,.795),new=TRUE,mar=c(3.2,4.3,.2,.4),mgp=c(2.5,.65,0))
 ymax<-max(summary$q75)*1.12
 plot(1,1,type="n",log="x",xlim=c(28,max(summary$x)*1.3),ylim=c(0,ymax),axes=FALSE,xlab="",ylab="",yaxs="i")
 yt<-pretty(c(0,ymax),5);abline(h=yt,col=grid,lwd=.7)
 axis(2,at=yt,las=1,tck=-.015,cex.axis=.95,col=grid)
 ss<-summary[summary$model=="M1b baseline",]
 axis(1,at=ss$x,labels=FALSE,tck=-.02,col=grid)
 mtext(ss$band,1,at=ss$x,line=.55,cex=.85)
 mtext(paste0(format(ss$games,big.mark=",",trim=TRUE)," games"),1,at=ss$x,line=1.55,cex=.74)
 mtext("Rating count (log scale; points at each band's median count)",1,line=2.7,cex=.94)
 mtext("|Posterior mean - raw mean| (points)",2,line=3.0,cex=.94)
 for(k in 1:2) {
  s<-summary[summary$model==c("M1b baseline","M1b-ExternalSD")[k],]
  x<-s$x*if(k==1).97 else 1.03;col<-c(blue,orange)[k]
  arrows(x,s$q25,x,s$q75,angle=90,code=3,length=.045,col=adjustcolor(col,.65),lwd=2)
  lines(x,s$median,col=col,lwd=2.5)
  points(x,s$median,pch=c(16,18)[k],col=col,cex=1.3)
 }
 text(650,ymax*.83,"30-40 ratings",adj=0,font=2,cex=1.1)
 text(650,ymax*.69,"Median adjustment: 0.2135 to 0.0710",adj=0,cex=1.05)
}
fig2<-function() {
 canvas("Designer effects with uncertainty",
  "Same 6,416 development games | 14 named designers with the most training games",
  "Points: posterior means. Bars: 95% credible intervals. Names are ordered by training-game count, not effect size.",
  "Associations after controlling for game features; not a causal ranking of designer ability. n = training games.")
 par(fig=c(.055,.96,.15,.795),new=TRUE,mar=c(2.9,13.0,.2,.5),mgp=c(2.1,.65,0))
 xlim<-range(c(d$lower95_baseline,d$upper95_baseline,d$lower95_external,d$upper95_external))+c(-.05,.05)
 plot(1,1,type="n",xlim=xlim,ylim=c(.45,14.55),axes=FALSE,xlab="",ylab="",yaxs="i")
 abline(v=pretty(xlim),col=grid,lwd=.7)
 abline(v=0,col=secondary,lty=2,lwd=1.5)
 y<-14:1
 abline(h=y,col=adjustcolor(grid,.5),lwd=.6)
 axis(2,at=y,labels=paste0(d$designer,"  (n = ",d$training_games,")"),las=1,tick=FALSE,cex.axis=.86)
 axis(1,at=pretty(xlim),tck=-.02,cex.axis=.95,col=grid)
 mtext("Designer random effect (rating points)",1,line=2.0,cex=.98)
 for(k in 1:2) {
  suffix<-c("baseline","external")[k];yy<-y+if(k==1).12 else -.12;col<-c(blue,orange)[k]
  segments(d[[paste0("lower95_",suffix)]],yy,d[[paste0("upper95_",suffix)]],yy,col=adjustcolor(col,.8),lwd=2.3)
  points(d[[paste0("mean_",suffix)]],yy,col=col,pch=c(16,18)[k],cex=1.04)
 }
}
for(i in 1:2) {
 stem<-c("fig1_shrinkage_by_rating_count","fig2_designer_effects")[i]
 png(file.path(out,paste0(stem,".png")),width=3200,height=1800,res=200,type="cairo",bg=surface)
 (if(i==1)fig1 else fig2)();dev.off()
 cairo_pdf(file.path(out,paste0(stem,".pdf")),width=16,height=9,family="sans",bg=surface)
 (if(i==1)fig1 else fig2)();dev.off()
}
writeLines(c("PASS: 6416 identical IDs/order/n/raw means in both models",
 "PASS: n30-40 medians agree with original verified report: 0.2135195395 / 0.0709525802",
 "PASS: IQR calculated across games; no posterior uncertainty interpretation",
 "PASS: top14 selected by descending training game count, name tie-break; minimum count 21",
 "PASS: effect intervals copied directly from full-four-chain saved 95% summaries",
 "Rendering only: no fitting, holdout scoring, source-result overwrite or deck edits"),file.path(out,"validation.txt"))
cat("PASS: two presentation figures exported as 3200x1800 PNG and 16x9-inch vector PDF\n")
