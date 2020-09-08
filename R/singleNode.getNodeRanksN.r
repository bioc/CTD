#' Generate the fixed , single-node diffusion node rankings, starting from
#' a given perturbed variable.
#'
#' This function calculates the node rankings starting from a given perturbed 
#' variable in a subset of variables in the network.
#' @param n - The index (out of a vector of node names) of the node ranking
#'            you want to calculate.
#' @param G - A list of probabilities with list names being the node names
#'            of the network.
#' @param S - A character vector of node names in the subset you want the 
#'            network walker to find.
#' @param num.misses - The number of "misses" the network walker will tolerate
#'                     before switching to fixed length codes for remaining
#'                     nodes to be found.
#' @param p1 - The probability that is preferentially distributed between
#'             network nodes by the probability diffusion algorithm based
#'             solely on network connectivity. The remaining probability
#'             (i.e., "p0") is uniformally distributed between network nodes,
#'             regardless of connectivity.
#' @param thresholdDiff - When the probability diffusion algorithm exchanges 
#'                        this amount or less between nodes, the algorithm 
#'                        returns up the call stack.
#' @param adj_mat - The adjacency matrix that encodes the edge weights for the 
#'                  network, G. 
#' @param verbose - If T, print statements will execute as progress is made.
#'                  Default is F.
#' @param out_dir - If specified, a image sequence will generate in the 
#'                  output directory specified.
#' @param useLabels - If T, node names will display next to their respective
#'                    nodes in the network. If F, node names will not display.
#'                    Only relevant if out_dir is specified. 
#' @param coords - The x and y coordinates for each node in the network, to 
#'                 remain static between images.
#' @return curr_ns - A character vector of node names in the order they
#'                   were drawn by the probability diffusion algorithm.
#' @keywords probability diffusion
#' @keywords network walker
#' @export singleNode.getNodeRanksN
#' @examples
#' data("Miller2015")
#' data_mx=Miller2015[-c(1,grep("x - ",rownames(Miller2015))),
#'                    grep("IEM", colnames(Miller2015))]
#' data_mx=apply(data_mx, c(1,2), as.numeric)
#' # Build an adjacency matrix for network G
#' adj_mat=matrix(0, nrow=nrow(data_mx),ncol=nrow(data_mx))
#' rows=sample(seq_len(ncol(adj_mat)),0.1*ncol(adj_mat))
#' cols=sample(seq_len(ncol(adj_mat)),0.1*ncol(adj_mat))
#' for(i in rows){for (j in cols){adj_mat[i,j]=rnorm(1,0,1)}}
#' colnames(adj_mat) = rownames(data_mx)
#' rownames(adj_mat) = rownames(data_mx)
#' G=vector("numeric", length=ncol(adj_mat))
#' names(G)=colnames(adj_mat)
#' # Get node rankings for the first metabolite in network G. 
#' ranks=singleNode.getNodeRanksN(1,G,p1=0.9,thresholdDiff=0.01,adj_mat)
#' # Make a movie of the network walker
#' S=names(G)[sample(seq_len(length(G)), 3, replace=FALSE)]
#' ig=graph.adjacency(adj_mat,mode="undirected",weighted=TRUE,add.colnames="name")
#' coords=layout.fruchterman.reingold(ig)
#' ranks = singleNode.getNodeRanksN(which(names(G)==S[1]),G,p1=0.9,
#'                                  thresholdDiff=0.01,adj_mat,S,
#'                                  log2(length(G)),FALSE,getwd())
singleNode.getNodeRanksN = function(n,G,p1,thresholdDiff,adj_mat,S=NULL,
                                    num.misses=NULL,verbose=F,out_dir="",
                                    useLabels=F,coords=NULL) {
    p0=1-p1
    if (is.null(S) && (!is.null(num.misses) || out_dir!="")) {
      print("You must also supply S if out_dir or num.misses is supplied")
      return(0)}
    if(verbose){print(sprintf("Node ranking %d of %d.",n,length(G)))}
    curr_ns = NULL # current node set
    stopIterating=FALSE
    startNode = names(G)[n]
    currGph = G
    numMisses = 0
    curr_ns = c(curr_ns, startNode)
    if(out_dir!=""){graph.netWalkSnapShot(adj_mat,G,out_dir,p1,curr_ns,S, 
                                          coords,length(curr_ns),useLabels)}
    while (stopIterating==FALSE) {
      currGph[seq_len(length(currGph))]=0 # clear probabilities
      baseP=p0/(length(currGph)-length(curr_ns))
      #set unvisited nodes to baseP
      currGph[!(names(currGph) %in% curr_ns)]=baseP
      currGph=graph.diffuseP1(p1,startNode,currGph,curr_ns,thresholdDiff,
                              adj_mat,verbose=F)
      # Sanity check. p1_event should add up to roughly p1
      p1_event = sum(unlist(currGph[!(names(currGph) %in% curr_ns)]))
      if (abs(p1_event-1)>thresholdDiff) {
        extra.prob.to.diffuse=1-p1_event
        currGph[names(curr_ns)]=0
        ind=!(names(currGph)%in%names(curr_ns))
        currGph[ind]=unlist(currGph[ind])+extra.prob.to.diffuse/sum(ind)}
      # Set startNode to a node that is the max probability in the new currGph
      maxProb=names(which.max(currGph))
      if(out_dir!=""){graph.netWalkSnapShot(adj_mat,G,out_dir,p1,curr_ns,S, 
                                            coords,length(curr_ns),
                                            useLabels)}
      # Break ties: When there are ties, choose the first of the winners.
      startNode = names(currGph[maxProb[1]])
      if (!is.null(S)) { # draw until all members of S are found
        if(startNode %in% S){numMisses=0}else{numMisses=numMisses+1}
        curr_ns = c(curr_ns, startNode)
        if (numMisses>num.misses || all(S %in% curr_ns)){stopIterating=T}
      } else { # keep drawing until you've drawn all nodes in G
        curr_ns = c(curr_ns, startNode)
        if(length(curr_ns)>=(length(G))){stopIterating=T}}
      if(out_dir!=""){graph.netWalkSnapShot(adj_mat,G,out_dir,p1,curr_ns,S, 
                                            coords,length(curr_ns),useLabels)}
    }
    return(curr_ns)
}
