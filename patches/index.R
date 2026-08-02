files <- list.files(pattern="diff$")
out <- as.list(files)
names(out) <- sub(".diff", "", files)
saveRDS(out, 'patches_idx.rds')

