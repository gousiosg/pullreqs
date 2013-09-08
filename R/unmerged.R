source(file = "R/utils.R")

manual.classif <- read.csv('unmerged-cross-validation.txt', stringsAsFactors = F, strip.white = T)

manual.classif$coder1.merged <- manual.classif$coder1.merged. == "merged"
manual.classif$coder2.merged <- manual.classif$coder2.merged. == "merged"
manual.classif$coder3.merged <- manual.classif$coder3.merged. == "yes"

manual.classif <- manual.classif[,c(1,3,6,9,11,12,13)]


manual.classif$coder1.tag <- apply(manual.classif, 1, function(row){if (row[5] == " TRUE") {"merged"} else {row[2]}})
manual.classif$coder2.tag <- apply(manual.classif, 1, function(row){if (row[6] == " TRUE") {"merged"} else {row[3]}})
manual.classif$coder3.tag <- apply(manual.classif, 1, function(row){if (row[7] == " TRUE") {"merged"} else {row[4]}})

manual.classif$coder1.tag <- apply(manual.classif, 1, function(row){if (row[2] == "") {"unknown"} else {row[2]}})
manual.classif$coder2.tag <- apply(manual.classif, 1, function(row){if (row[3] == "") {"unknown"} else {row[3]}})
manual.classif$coder3.tag <- apply(manual.classif, 1, function(row){if (row[4] == "") {"unknown"} else {row[4]}})

manual.classif <- manual.classif[,c(2,3,4)]

printf("Cases where tag1 != tag2: %d", nrow(subset(manual.classif, coder1.tag != coder2.tag)))
printf("Cases where tag2 != tag3: %d", nrow(subset(head(manual.classif, 50), coder2.tag != coder3.tag)))

categories <- c("obsolete", "process", "conflict", "superseded", "duplicate", 
                "incorrect implementation", "superfluous", "tests", "deferred",
                "merged", "unknown")

for (cat in categories) {
  printf("Category: %s, coder 1: %f", cat, 
         (nrow(subset(manual.classif, coder1.tag == cat)) + nrow(subset(manual.classif, coder2.tag == cat))) / 200)
  #(nrow(subset(manual.classif, coder1.tag == cat)) + nrow(subset(manual.classif, coder2.tag == cat))) / 200
}
