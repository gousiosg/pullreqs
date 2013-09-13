source(file = "R/utils.R")

categories <- c("obsolete", "conflict", "superseded", "process", "duplicate", 
                "incorrect implementation", "superfluous", "tests", "deferred",
                "merged", "unknown")

# Cross validation sample
cross.val <- read.csv('data/unmerged-cross-validation.txt', stringsAsFactors = F, strip.white = T)

cross.val$coder1.merged <- cross.val$coder1.merged. == "merged"
cross.val$coder2.merged <- cross.val$coder2.merged. == "merged"
cross.val$coder3.merged <- cross.val$coder3.merged. == "yes"

cross.val <- cross.val[,c(1,3,6,9,11,12,13)]

cross.val$coder1.tag <- apply(cross.val, 1, function(row){if (row[5] == " TRUE") {"merged"} else {row[2]}})
cross.val$coder2.tag <- apply(cross.val, 1, function(row){if (row[6] == " TRUE") {"merged"} else {row[3]}})
cross.val$coder3.tag <- apply(cross.val, 1, function(row){if (row[7] == " TRUE") {"merged"} else {row[4]}})

cross.val$coder1.tag <- apply(cross.val, 1, function(row){if (row[2] == "") {"unknown"} else {row[2]}})
cross.val$coder2.tag <- apply(cross.val, 1, function(row){if (row[3] == "") {"unknown"} else {row[3]}})
cross.val$coder3.tag <- apply(cross.val, 1, function(row){if (row[4] == "") {"unknown"} else {row[4]}})

cross.val <- cross.val[,c(2,3,4)]

printf("Cases where tag1 != tag2: %d", nrow(subset(cross.val, coder1.tag != coder2.tag)))
printf("Cases where tag2 != tag3: %d", nrow(subset(head(cross.val, 50), coder2.tag != coder3.tag)))

for (cat in categories) {
  printf("Category: %s, coder 1: %f", cat, 
         (nrow(subset(cross.val, coder1.tag == cat)) + nrow(subset(cross.val, coder2.tag == cat))) / 200)
  #(nrow(subset(cross.val, coder1.tag == cat)) + nrow(subset(cross.val, coder2.tag == cat))) / 200
}

# Actual sample
sample.250 <- read.csv('data/unmerged-250.txt', stringsAsFactors = F, strip.white = T)

sample.250 <- subset(sample.250, tag != "")

all.coding <- c(sample.250$tag, cross.val$coder2.tag)
all.coding <- table(all.coding)

for (cat in categories) {
  printf("Category: %s, sample350: %f", cat, (all.coding[cat]/350) * 100)
}
