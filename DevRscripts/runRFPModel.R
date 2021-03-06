rm(list=ls())
library(ribModel)

genome <- initializeGenomeObject(file = 
         "../data/rfp/rfp.counts.by.codon.and.gene.GSE63789.wt.csv", FALSE)


sphi_init <- c(2)
numMixtures <- 1
mixDef <- "allUnique"
geneAssignment <- c(rep(1, genome$getGenomeSize(F)))
parameter <- initializeParameterObject(genome, sphi_init, numMixtures, geneAssignment, model= "RFP", split.serine = TRUE, mixture.definition = mixDef)
#parameter <- initializeParameterObject(model="RFP", restart.file="10_restartFile.rst")

samples <- 10
thining <- 10
adaptiveWidth <- 10
mcmc <- initializeMCMCObject(samples=samples, thining=thining, adaptive.width=adaptiveWidth, 
                             est.expression=TRUE, est.csp=TRUE, est.hyper=TRUE)

model <- initializeModelObject(parameter, "RFP")
setRestartSettings(mcmc, "restartFile.rst", adaptiveWidth, TRUE)
system.time(
  runMCMC(mcmc, genome, model, 8)
)






# plots different aspects of trace
trace <- parameter$getTraceObject()
writeParameterObject(parameter, file="RFPObject1.Rdat")
writeMCMCObject(mcmc, file="MCMCObject1.Rdat")


pdf("RFP_Genome_allUnique_startCSP_True_startPhi_true_adaptSphi_True.pdf")
plot(mcmc) #plots the whole logliklihood trace

#Here I take a subset of the trace values for the logliklihood trace and plot them.
#The primary reason for doing this is the "jump" that throws the scale of the graph
#at the beginning is removed by taking out the beginning values.
loglik.trace <- mcmc$getLogLikelihoodTrace()
start <- length(loglik.trace) * 0.5 #the multiplier determines how much of the beginning trace is 
                                    #eliminated.

logL <- logL <- mean(loglik.trace[start:length(loglik.trace)]) #get the mean for the subset
plot(loglik.trace[start:length(loglik.trace)], type="l", main=paste("logL:", logL), xlab="Sample", ylab="log(Likelihood)")
grid (NULL,NULL, lty = 6, col = "cornsilk2")


plot(trace, what = "MixtureProbability")
plot(trace, what = "Mphi")
plot(trace, what = "Sphi")
plot(trace, what = "ExpectedPhi")
loglik.trace <- mcmc$getLogLikelihoodTrace()
acf(loglik.trace)
acf(loglik.trace[start:length(loglik.trace)])
dev.off()



pdf("RFP_CSP_Values_Mixture1.pdf", width = 11, height = 20)
#plot(trace, what = "Expression", geneIndex = 905) #used to make sure gene stabalized, not really needed now
plot(trace, what = "Alpha", mixture = 1)
plot(trace, what = "LambdaPrime", mixture = 1)
dev.off()





pdf("ConfidenceIntervalsForAlphaAndLambdaPrime.pdf")

#eventually this will need loop over all categories if there are multiple mixtures
cat <- 1
proposal <- FALSE
alphaList <- numeric (61)
lambdaPrimeList <- numeric (61)
waitingTimes <- numeric(61)
alpha.ci <- matrix(0, ncol=2, nrow=61)
lambdaPrime.ci <- matrix(0, ncol=2, nrow=61)
psiList <- numeric(genome$getGenomeSize(F))
ids <- numeric(genome$getGenomeSize(F))
codonList <- codons()
for (i in 1:61)
{
  codon <- codonList[i]
  alphaList[i] <- parameter$getCodonSpecificPosteriorMean(cat, samples * 0.5, codon, 0, FALSE)
  alphaTrace <- trace$getCodonSpecificParameterTraceByMixtureElementForCodon(1, codon, 0, FALSE)
  alpha.ci[i,] <- quantile(alphaTrace[(samples * 0.5):samples], probs = c(0.025,0.975))
  
  
  lambdaPrimeList[i] <- parameter$getCodonSpecificPosteriorMean(cat, samples * 0.5, codon, 1, FALSE)
  lambdaPrimeTrace <- trace$getCodonSpecificParameterTraceByMixtureElementForCodon(1, codon, 1, FALSE)
  lambdaPrime.ci[i,] <- quantile(lambdaPrimeTrace[(samples * 0.5):samples], probs = c(0.025,0.975))
  waitingTimes[i] <- alphaList[i] * lambdaPrimeList[i]
}

waitRates <- numeric(61)
for (i in 1:61) {
  waitRates[i] <- (1.0/waitingTimes[i])
}


for (geneIndex in 1:genome$getGenomeSize(FALSE)) {
  psiList[geneIndex] <- parameter$getSynthesisRatePosteriorMeanByMixtureElementForGene(samples * 0.5, geneIndex, 1)
}

for (i in 1:genome$getGenomeSize(FALSE))
{
  g <- genome$getGeneByIndex(i, FALSE)
  ids[i] <- g$id
}

#Plot confidence intervals for alpha and lambda prime
plot(NULL, NULL, xlim=range(1:61, na.rm = T), ylim=range(alpha.ci), 
     main = "Confidence Intervals for Alpha Parameter", xlab = "Codons", 
     ylab = "Estimated values", axes=F) 
confidenceInterval.plot(x = 1:61, y = alphaList, sd.y = alpha.ci)
axis(2)
axis(1, tck = 0.02, labels = codonList[1:61], at=1:61, las=2, cex.axis=.6)

plot(NULL, NULL, xlim=range(1:61, na.rm = T), ylim=range(lambdaPrime.ci), 
     main = "Confidence Intervals for LambdaPrime Parameter", xlab = "Codons", 
     ylab = "Estimated values", axes=F) 
confidenceInterval.plot(x = 1:61, y = lambdaPrimeList, sd.y = lambdaPrime.ci)
axis(2)
axis(1, tck = 0.02, labels = codonList[1:61], at=1:61, las=2, cex.axis=.6)



#corrolation between RFPModel and Premal's wait rates
#load Premal's data
X <- read.table("../data/rfp/codon.specific.translation.rates.table.csv", header = TRUE, sep =",")
X <- X[order(X[,1]) , ]
XM <- matrix(c(X[,1], X[,2]), ncol = 2, byrow = FALSE)



Y <- data.frame(codonList[-c(62,63,64)], waitRates)
colnames(Y) <- c("Codon", "PausingTimeRates")
Y <- Y[order(Y[,1]) , ]

plot(NULL, NULL, xlim=range(XM[,2], na.rm = T), ylim=range(Y[,2]), 
     main = "Correlation Between Premal and RFP Model Pausing Time Rates", xlab = "Premal's Rates", ylab = "RFP's Rates")
upper.panel.plot(XM[,2], Y[,2])
dev.off()





#Will write csv files based off posterior for alpha, lambda prime, and psi
m <- matrix(c(codonList[-c(62,63,64)], alphaList), ncol = 2, byrow = FALSE)
colnames(m) <- c("Codon", "Alpha")
write.table(m, "RFPAlphaValues.csv", sep = ",", quote = F, row.names = F, col.names = T)

m <- matrix(c(codonList[-c(62,63,64)], lambdaPrimeList), ncol = 2, byrow = FALSE)
colnames(m) <- c("Codon", "LambdaPrime")
write.table(m, "RFPLambdaPrimeValues.csv", sep = ",", quote = F, row.names = F, col.names = T)


m <- matrix(c(ids, psiList, psiList), ncol = 3, byrow = FALSE)
colnames(m) <- c("Gene", "PsiValue", "PsiValue")
write.table(m, "RFPPsiValues.csv", sep = ",", quote = F, row.names = F, col.names = T)