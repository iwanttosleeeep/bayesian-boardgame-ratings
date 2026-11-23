source("code/P4/M1b_prepare.R")
d<-read.csv("dev_subsample.csv",fileEncoding="UTF-8",stringsAsFactors=FALSE)
p<-m1b_prepare(d)
g<-read.csv("outputs/P4/resources/development_designer_groups.csv",stringsAsFactors=FALSE)
repeat_ids<-g$designer_index[g$games>=2]
rows<-which(p$data$known==1 & p$data$designer %in% repeat_ids)
X<-p$data$X[rows,,drop=FALSE]
group<-p$data$designer[rows]
within<-X
for(j in unique(group)) within[group==j,]<-sweep(X[group==j,,drop=FALSE],2,colMeans(X[group==j,,drop=FALSE]),"-")
variation<-data.frame(term=colnames(X),
  repeated_groups_with_variation=vapply(seq_len(ncol(X)),function(k)
    sum(vapply(split(X[,k],group),function(x)length(unique(x))>1,FALSE)),0L),
  within_group_sd=sqrt(colSums(within^2)/(nrow(X)-length(unique(group)))))
write.csv(variation,"outputs/P4/resources/within_designer_predictor_variation.csv",row.names=FALSE)
pairs<-g$games*(g$games-1)/2
metrics<-c(repeated_groups=length(repeat_ids),repeated_games=length(rows),
  independent_within_group_contrasts=length(rows)-length(repeat_ids),
  rank_of_within_group_design=qr(within)$rank,
  largest_designer_pair_fraction=max(pairs)/sum(pairs),
  top10_designer_pair_fraction=sum(sort(pairs,decreasing=TRUE)[1:10])/sum(pairs),
  median_sd_log1p_n_repeated=median(g$sd_log1p_n[g$games>=2]))
write.csv(data.frame(metric=names(metrics),value=unname(metrics)),"outputs/P4/resources/repeat_information_summary.csv",row.names=FALSE)
cat(paste(names(metrics),round(metrics,4),collapse="\n"),"\n")
