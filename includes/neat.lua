

function fai_neat_init(num_inputs, num_outputs)
	local Neat = {}
	Neat.inputs = num_inputs + 1
	Neat.outputs = num_outputs

	Neat.population = 300
	Neat.deltaDisjoint = 2.0
	Neat.deltaWeights = 0.4
	Neat.deltaThreshold = 1.0

	Neat.staleSpecies = 15

	Neat.mutateConnectionsChance = 0.25
	Neat.perturbChance = 0.90
	Neat.crossoverChance = 0.75
	Neat.linkMutationChance = 2.0
	Neat.nodeMutationChance = 0.50
	Neat.biasMutationChance = 0.40
	Neat.stepSize = 0.1
	Neat.disableMutationChance = 0.4
	Neat.enableMutationChance = 0.2

	Neat.maxNodes = 1000000

	Neat.evaluations = {}
	Neat.searchedOnce = false
	Neat.lastGenomeSelected = 1

	Neat.pool = fai_neat_newPool(Neat)
	return Neat
end

--create a first population of genomes and group them into species
function fai_neat_initializePool(Neat)
	for i=1,Neat.population do
		basic = fai_neat_basicGenome(Neat)
		fai_neat_addToSpecies(Neat,basic)
	end
end
 
 --get the outputs of selected genome
function fai_neat_evaluate(Neat, evaluation_num, inputs)
		fai_neat_checkEvaluation(Neat,evaluation_num)

        local species = Neat.pool.species[Neat.evaluations[evaluation_num].species]
        local genome = species.genomes[Neat.evaluations[evaluation_num].genome]
 
        return fai_neat_evaluateNetwork(Neat, genome.network, inputs)
end

--rate selected genome with an fitness value
function fai_neat_rate(Neat, evaluation_num, fitness)
	fai_neat_checkEvaluation(Neat,evaluation_num)

    local species = Neat.pool.species[Neat.evaluations[evaluation_num].species]
    local genome = species.genomes[Neat.evaluations[evaluation_num].genome]

	genome.fitness = fitness

    if fitness > Neat.pool.maxFitness then
            Neat.pool.maxFitness = fitness
    end
	
	fai_neat_removeEvaluation(Neat, evaluation_num)
end

--save population
function fai_neat_save(Neat,filename)
        local file = io.open(filename, "w")
        file:write(Neat.pool.generation .. "\n")
        file:write(Neat.pool.maxFitness .. "\n")
        file:write(#Neat.pool.species .. "\n")
        for n,species in pairs(Neat.pool.species) do
                file:write(species.topFitness .. "\n")
                file:write(species.staleness .. "\n")
                file:write(#species.genomes .. "\n")
                for m,genome in pairs(species.genomes) do
                        file:write(genome.fitness .. "\n")
                        file:write(genome.maxneuron .. "\n")
                        for mutation,rate in pairs(genome.mutationRates) do
                                file:write(mutation .. "\n")
                                file:write(rate .. "\n")
                        end
                        file:write("done\n")
                       
                        file:write(#genome.genes .. "\n")
                        for l,gene in pairs(genome.genes) do
                                file:write(gene.into .. " ")
                                file:write(gene.out .. " ")
                                file:write(gene.weight .. " ")
                                file:write(gene.innovation .. " ")
                                if(gene.enabled) then
                                        file:write("1\n")
                                else
                                        file:write("0\n")
                                end
                        end
                end
        end
        file:close()
end
 
 --load population
function fai_neat_load(Neat, filename)
        local file = io.open(filename, "r")
		if file then
			Neat.pool = fai_neat_newPool(Neat)
			Neat.pool.generation = file:read("*number")
			Neat.pool.maxFitness = file:read("*number")
			local numSpecies = file:read("*number")
			for s=1,numSpecies do
					local species =  fai_neat_newSpecies(Neat)
					table.insert(Neat.pool.species, species)
					species.topFitness = file:read("*number")
					species.staleness = file:read("*number")
					local numGenomes = file:read("*number")
					for g=1,numGenomes do
							local genome = fai_neat_newGenome(Neat)
							table.insert(species.genomes, genome)
							genome.fitness = file:read("*number")
							genome.maxneuron = file:read("*number")
							local line = file:read("*line")
							while line ~= "done" do
									genome.mutationRates[line] = file:read("*number")
									line = file:read("*line")
							end
							local numGenes = file:read("*number")
							for n=1,numGenes do
									local gene =  fai_neat_newGene(Neat)
									table.insert(genome.genes, gene)
									local enabled
									gene.into, gene.out, gene.weight, gene.innovation, enabled = file:read("*number", "*number", "*number", "*number", "*number")
									if enabled == 0 then
											gene.enabled = false
									else
											gene.enabled = true
									end
                               
							end
					end
			end
			file:close()
		end
end

-----------------------------------------------------------------------------------------------------------
-- These are private functions and should not be used from outside of Neat
-----------------------------------------------------------------------------------------------------------

function fai_neat_evaluateNetwork(Neat, network, inputs)
        table.insert(inputs, 1)
        if #inputs ~= Neat.inputs then
                return {}
        end
       
        for i=1,Neat.inputs do
                network.neurons[i].value = inputs[i]
        end
       
        for _,neuron in pairs(network.neurons) do
                local sum = 0
                for j = 1,#neuron.incoming do
                        local incoming = neuron.incoming[j]
                        local other = network.neurons[incoming.into]
                        sum = sum + incoming.weight * other.value
                end
               
                if #neuron.incoming > 0 then
                        neuron.value = fai_neat_sigmoid(Neat,sum)
                end
        end
       
        local outputs = {}
        for o=1,Neat.outputs do
			outputs[o] = network.neurons[Neat.maxNodes+o].value
        end
       
        return outputs
end

function fai_neat_newEvaluation()
	local evaluation = {}
	evaluation.species = 1
	evaluation.genome = 1

	return evaluation
end

function fai_neat_checkEvaluation(Neat, evaluation_num)
	if (Neat.evaluations[evaluation_num] == nil) then
		Neat.evaluations[evaluation_num] = fai_neat_newEvaluation()
		Neat.lastGenomeSelected = 1
		Neat.searchedOnce = false
		while fai_neat_shouldNotBeMeasured(Neat, evaluation_num) do
			if Neat.evaluations[evaluation_num].genome >= #Neat.pool.species[Neat.evaluations[evaluation_num].species].genomes then
				Neat.evaluations[evaluation_num].genome = 1
				Neat.evaluations[evaluation_num].species = Neat.evaluations[evaluation_num].species + 1
				if Neat.evaluations[evaluation_num].species > #Neat.pool.species then
					if searchedOnce then
						fai_neat_newGeneration(Neat)
						Neat.evaluations[evaluation_num] = fai_neat_newEvaluation()
					else
						Neat.lastGenomeSelected = 1
						searchedOnce = true
					end
					Neat.evaluations[evaluation_num].species = 1
				end
			else
				Neat.evaluations[evaluation_num].genome = Neat.evaluations[evaluation_num].genome + 1
				Neat.lastGenomeSelected = Neat.lastGenomeSelected + 1
			end
		end
		local species = Neat.pool.species[Neat.evaluations[evaluation_num].species]
		local genome = species.genomes[Neat.evaluations[evaluation_num].genome]
		if #genome.network then
			genome.evaluated = true
    		fai_neat_generateNetwork(Neat,genome)
		end
	end
end

function fai_neat_removeEvaluation(Neat, evaluation_num)
    local species = Neat.pool.species[Neat.evaluations[evaluation_num].species]
    local genome = species.genomes[Neat.evaluations[evaluation_num].genome]

	genome.evaluated = false
	Neat.evaluations[evaluation_num] = nil
end

function fai_neat_newPool(Neat)
        local pool = {}
        pool.species = {}
        pool.generation = 0
        pool.innovation = Neat.outputs
        pool.maxFitness = 0
       
        return pool
end

function fai_neat_newSpecies(Neat)
        local species = {}
        species.topFitness = 0
        species.staleness = 0
        species.genomes = {}
        species.averageFitness = 0
       
        return species
end

function fai_neat_addToSpecies(Neat, child)
        local foundSpecies = false
        for s=1,#Neat.pool.species do
                local species = Neat.pool.species[s]
                if not foundSpecies and fai_neat_sameSpecies(Neat, child, species.genomes[1]) then
                        table.insert(species.genomes, child)
                        foundSpecies = true
                end
        end
       
        if not foundSpecies then
                local childSpecies = fai_neat_newSpecies(Neat)
                table.insert(childSpecies.genomes, child)
                table.insert(Neat.pool.species, childSpecies)
        end
end

function fai_neat_sameSpecies(Neat,genome1, genome2)
        local dd = Neat.deltaDisjoint*fai_neat_disjoint(Neat,genome1.genes, genome2.genes)
        local dw = Neat.deltaWeights*fai_neat_weights(Neat,genome1.genes, genome2.genes)
        return dd + dw < Neat.deltaThreshold
end

--remove weak genomes of each species
function fai_neat_cullSpecies(Neat, cutToOne)
        for s = 1,#Neat.pool.species do
                local species = Neat.pool.species[s]
               
                table.sort(species.genomes, function (a,b)
                        return (a.fitness > b.fitness)
                end)
               
                local remaining = math.ceil(#species.genomes/2)
                if cutToOne then
                        remaining = 1
                end
                while #species.genomes > remaining do
                        table.remove(species.genomes)
                end
        end
end

--remove species that do not evolve
function fai_neat_removeStaleSpecies(Neat)
        local survived = {}
 
        for s = 1,#Neat.pool.species do
                local species = Neat.pool.species[s]
               
                table.sort(species.genomes, function (a,b)
                        return (a.fitness > b.fitness)
                end)
               
                if species.genomes[1].fitness > species.topFitness then
                        species.topFitness = species.genomes[1].fitness
                        species.staleness = 0
                else
                        species.staleness = species.staleness + 1
                end
                if species.staleness < Neat.staleSpecies or species.topFitness >= Neat.pool.maxFitness then
                        table.insert(survived, species)
                end
        end
 
        Neat.pool.species = survived
end

function fai_neat_calculateAverageFitness(Neat,species)
        local total = 0
       
        for g=1,#species.genomes do
                local genome = species.genomes[g]
                total = total + genome.globalRank
        end
       
        species.averageFitness = total / #species.genomes
end

function fai_neat_totalAverageFitness(Neat)
        local total = 0
        for s = 1,#Neat.pool.species do
                local species = Neat.pool.species[s]
                total = total + species.averageFitness
        end
 
        return total
end

function fai_neat_removeWeakSpecies(Neat)
        local survived = {}
 
        local sum = fai_neat_totalAverageFitness(Neat)
        for s = 1,#Neat.pool.species do
                local species = Neat.pool.species[s]
                breed = math.floor(species.averageFitness / sum * Neat.population)
                if breed >= 1 then
                        table.insert(survived, species)
                end
        end
 
        Neat.pool.species = survived
end

function fai_neat_breedChild(Neat,species)
        local child = {}
        if math.random() < Neat.crossoverChance then
                g1 = species.genomes[math.random(1, #species.genomes)]
                g2 = species.genomes[math.random(1, #species.genomes)]
                child = fai_neat_crossover(Neat,g1, g2)
        else
                g = species.genomes[math.random(1, #species.genomes)]
                child = fai_neat_copyGenome(Neat,g)
        end
       
        fai_neat_mutate(Neat,child)
       
        return child
end



function fai_neat_newGenome(Neat)
        local genome = {}
        genome.genes = {}
        genome.fitness = 0
        genome.adjustedFitness = 0
        genome.network = {}
        genome.maxneuron = 0
        genome.globalRank = 0
        genome.mutationRates = {}
        genome.mutationRates["connections"] = Neat.mutateConnectionsChance
        genome.mutationRates["link"] = Neat.linkMutationChance
        genome.mutationRates["bias"] = Neat.biasMutationChance
        genome.mutationRates["node"] = Neat.nodeMutationChance
        genome.mutationRates["enable"] = Neat.enableMutationChance
        genome.mutationRates["disable"] = Neat.disableMutationChance
        genome.mutationRates["step"] = Neat.stepSize

		genome.evaluated = false
       
        return genome
end

function fai_neat_basicGenome(Neat)
	local genome = fai_neat_newGenome(Neat)
	local innovation = 1

	genome.maxneuron = Neat.inputs
	fai_neat_mutate(Neat,genome)

	return genome
end

function fai_neat_copyGenome(Neat,genome)
        local genome2 = fai_neat_newGenome(Neat)
        for g=1,#genome.genes do
                table.insert(genome2.genes, fai_neat_copyGene(Neat, genome.genes[g]))
        end
        genome2.maxneuron = genome.maxneuron
        genome2.mutationRates["connections"] = genome.mutationRates["connections"]
        genome2.mutationRates["link"] = genome.mutationRates["link"]
        genome2.mutationRates["bias"] = genome.mutationRates["bias"]
        genome2.mutationRates["node"] = genome.mutationRates["node"]
        genome2.mutationRates["enable"] = genome.mutationRates["enable"]
        genome2.mutationRates["disable"] = genome.mutationRates["disable"]
       
        return genome2
end


function fai_neat_mutate(Neat,genome)
        for mutation,rate in pairs(genome.mutationRates) do
                if math.random(1,2) == 1 then
                        genome.mutationRates[mutation] = 0.95*rate
                else
                        genome.mutationRates[mutation] = 1.05263*rate
                end
        end
 
        if math.random() < genome.mutationRates["connections"] then
                fai_neat_pointMutate(Neat,genome)
        end
       
        local p = genome.mutationRates["link"]
        while p > 0 do
                if math.random() < p then
                        fai_neat_linkMutate(Neat,genome, false)
                end
                p = p - 1
        end
 
        p = genome.mutationRates["bias"]
        while p > 0 do
                if math.random() < p then
                        fai_neat_linkMutate(Neat,genome, true)
                end
                p = p - 1
        end
       
        p = genome.mutationRates["node"]
        while p > 0 do
                if math.random() < p then
                        fai_neat_nodeMutate(Neat,genome)
                end
                p = p - 1
        end
       
        p = genome.mutationRates["enable"]
        while p > 0 do
                if math.random() < p then
                        fai_neat_enableDisableMutate(Neat,genome, true)
                end
                p = p - 1
        end
 
        p = genome.mutationRates["disable"]
        while p > 0 do
                if math.random() < p then
                        fai_neat_enableDisableMutate(Neat,genome, false)
                end
                p = p - 1
        end
end

--set new weights for genome genes
function fai_neat_pointMutate(Neat,genome)
        local step = genome.mutationRates["step"]
       
        for i=1,#genome.genes do
                local gene = genome.genes[i]
                if math.random() < Neat.perturbChance then
                        gene.weight = gene.weight + math.random() * step*2 - step
                else
                        gene.weight = math.random()*4-2
                end
        end
end

--create a new gene
function fai_neat_linkMutate(Neat,genome, forceBias)
        local neuron1 = fai_neat_randomNeuron(Neat, genome.genes, false)
        local neuron2 = fai_neat_randomNeuron(Neat, genome.genes, true)
         
        local newLink = fai_neat_newGene(Neat)
        if neuron1 <= Neat.inputs and neuron2 <= Neat.inputs then
                --Both input nodes
                return
        end
        if neuron2 <= Neat.inputs then
                -- Swap output and input
                local temp = neuron1
                neuron1 = neuron2
                neuron2 = temp
        end
 
        newLink.into = neuron1
        newLink.out = neuron2
        if forceBias then
                newLink.into = Neat.inputs
        end
       
        if fai_neat_containsLink(Neat,genome.genes, newLink) then
                return
        end
        newLink.innovation = fai_neat_newInnovation(Neat)
        newLink.weight = math.random()*4-2
       
        table.insert(genome.genes, newLink)
end

--make two chain genes out of one gene
function fai_neat_nodeMutate(Neat,genome)
        if #genome.genes == 0 then
                return
        end
 
        genome.maxneuron = genome.maxneuron + 1
 
        local gene = genome.genes[math.random(1,#genome.genes)]
        if not gene.enabled then
                return
        end
        gene.enabled = false
       
        local gene1 = fai_neat_copyGene(Neat,gene)
        gene1.out = genome.maxneuron
        gene1.weight = 1.0
        gene1.innovation = fai_neat_newInnovation(Neat)
        gene1.enabled = true
        table.insert(genome.genes, gene1)
       
        local gene2 = fai_neat_copyGene(Neat,gene)
        gene2.into = genome.maxneuron
        gene2.innovation = fai_neat_newInnovation(Neat)
        gene2.enabled = true
        table.insert(genome.genes, gene2)
end

-- change the enabled state of a gene
function fai_neat_enableDisableMutate(Neat, genome, enable)
        local candidates = {}
        for _,gene in pairs(genome.genes) do
                if gene.enabled == not enable then
                        table.insert(candidates, gene)
                end
        end
       
        if #candidates == 0 then
                return
        end
       
        local gene = candidates[math.random(1,#candidates)]
        gene.enabled = not gene.enabled
end


function fai_neat_crossover(Neat, g1, g2)
        -- Make sure g1 is the higher fitness genome
        if g2.fitness > g1.fitness then
                tempg = g1
                g1 = g2
                g2 = tempg
        end
 
        local child = fai_neat_newGenome(Neat)
       
        local innovations2 = {}
        for i=1,#g2.genes do
                local gene = g2.genes[i]
                innovations2[gene.innovation] = gene
        end
       
        for i=1,#g1.genes do
                local gene1 = g1.genes[i]
                local gene2 = innovations2[gene1.innovation]
                if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
                        table.insert(child.genes, fai_neat_copyGene(Neat,gene2))
                else
                        table.insert(child.genes, fai_neat_copyGene(Neat,gene1))
                end
        end
       
        child.maxneuron = math.max(g1.maxneuron,g2.maxneuron)
       
        for mutation,rate in pairs(g1.mutationRates) do
                child.mutationRates[mutation] = rate
        end
       
        return child
end

function fai_neat_generateNetwork(Neat, genome)
        local network = {}
        network.neurons = {}
       
        for i=1,Neat.inputs do
                network.neurons[i] = fai_neat_newNeuron(Neat)
        end
       
        for o=1,Neat.outputs do
                network.neurons[Neat.maxNodes+o] = fai_neat_newNeuron(Neat)
        end
       
        table.sort(genome.genes, function (a,b)
                return (a.out < b.out)
        end)
        for i=1,#genome.genes do
                local gene = genome.genes[i]
                if gene.enabled then
                        if network.neurons[gene.out] == nil then
                                network.neurons[gene.out] = fai_neat_newNeuron(Neat)
                        end
                        local neuron = network.neurons[gene.out]
                        table.insert(neuron.incoming, gene)
                        if network.neurons[gene.into] == nil then
                                network.neurons[gene.into] = fai_neat_newNeuron(Neat)
                        end
                end
        end
        
        genome.network = network
end

function fai_neat_shouldNotBeMeasured(Neat, evaluation_num)
        local species = Neat.pool.species[Neat.evaluations[evaluation_num].species]
        local genome = species.genomes[Neat.evaluations[evaluation_num].genome]
		if (genome.fitness == 0 and genome.evaluated == Neat.searchedOnce) then
			return false
		else
			return true
		end
end

function fai_neat_containsLink(Neat,genes, link)
        for i=1,#genes do
                local gene = genes[i]
                if gene.into == link.into and gene.out == link.out then
                        return true
                end
        end
end

function fai_neat_disjoint(Neat,genes1, genes2)
        local i1 = {}
        for i = 1,#genes1 do
                local gene = genes1[i]
                i1[gene.innovation] = true
        end
 
        local i2 = {}
        for i = 1,#genes2 do
                local gene = genes2[i]
                i2[gene.innovation] = true
        end
       
        local disjointGenes = 0
        for i = 1,#genes1 do
                local gene = genes1[i]
                if not i2[gene.innovation] then
                        disjointGenes = disjointGenes+1
                end
        end
       
        for i = 1,#genes2 do
                local gene = genes2[i]
                if not i1[gene.innovation] then
                        disjointGenes = disjointGenes+1
                end
        end
       
        local n = math.max(#genes1, #genes2)
       
        return disjointGenes / n
end
 
function fai_neat_weights(Neat,genes1, genes2)
        local i2 = {}
        for i = 1,#genes2 do
                local gene = genes2[i]
                i2[gene.innovation] = gene
        end
 
        local sum = 0
        local coincident = 0
        for i = 1,#genes1 do
                local gene = genes1[i]
                if i2[gene.innovation] ~= nil then
                        local gene2 = i2[gene.innovation]
                        sum = sum + math.abs(gene.weight - gene2.weight)
                        coincident = coincident + 1
                end
        end
       
        return sum / coincident
end

function fai_neat_newGene(Neat)
        local gene = {}
        gene.into = 0
        gene.out = 0
        gene.weight = 0.0
        gene.enabled = true
        gene.innovation = 0
       
        return gene
end

function fai_neat_copyGene(Neat,gene)
        local gene2 = fai_neat_newGene(Neat)
        gene2.into = gene.into
        gene2.out = gene.out
        gene2.weight = gene.weight
        gene2.enabled = gene.enabled
        gene2.innovation = gene.innovation
       
        return gene2
end

function fai_neat_newInnovation(Neat)
        Neat.pool.innovation = Neat.pool.innovation + 1
        return Neat.pool.innovation
end

function fai_neat_newNeuron(Neat)
        local neuron = {}
        neuron.incoming = {}
        neuron.value = 0.0
       
        return neuron
end

function fai_neat_randomNeuron(Neat,genes, nonInput)
        local neurons = {}
        if not nonInput then
                for i=1,Neat.inputs do
                        neurons[i] = true
                end
        end
        for o=1,Neat.outputs do
                neurons[Neat.maxNodes+o] = true
        end
        for i=1,#genes do
                if (not nonInput) or genes[i].into > Neat.inputs then
                        neurons[genes[i].into] = true
                end
                if (not nonInput) or genes[i].out > Neat.inputs then
                        neurons[genes[i].out] = true
                end
        end
 
        local count = 0
        for _,_ in pairs(neurons) do
                count = count + 1
        end
        local n = math.random(1, count)
       
        for k,v in pairs(neurons) do
                n = n-1
                if n == 0 then
                        return k
                end
        end
       
        return 0
end

function fai_neat_newGeneration(Neat)
		fai_neat_save(Neat,"bots/savefile.sf")
		Neat.evaluations = {}
        fai_neat_cullSpecies(Neat,false) -- Cull the bottom half of each species
        fai_neat_rankGlobally(Neat)
        fai_neat_removeStaleSpecies(Neat)
        fai_neat_rankGlobally(Neat)
        for s = 1,#Neat.pool.species do
                local species = Neat.pool.species[s]
                fai_neat_calculateAverageFitness(Neat,species)
        end
        fai_neat_removeWeakSpecies(Neat)
        local sum = fai_neat_totalAverageFitness(Neat)
        local children = {}
        for s = 1,#Neat.pool.species do
                local species = Neat.pool.species[s]
                breed = math.floor(species.averageFitness / sum * Neat.population) - 1
                for i=1,breed do
                        table.insert(children, fai_neat_breedChild(Neat,species))
                end
        end
        fai_neat_cullSpecies(Neat,true) -- Cull all but the top member of each species
        while #children + #Neat.pool.species < Neat.population do
                local species = Neat.pool.species[math.random(1, #Neat.pool.species)]
                table.insert(children, fai_neat_breedChild(Neat,species))
        end
        for c=1,#children do
                local child = children[c]
                fai_neat_addToSpecies(Neat,child)
        end
		--reset fitness
        for s = 1,#Neat.pool.species do
                local species = Neat.pool.species[s]
                for g = 1,#species.genomes do
						species.genomes[g].fitness = 0
                end
        end
		Neat.pool.maxFitness = 0
       
        Neat.pool.generation = Neat.pool.generation + 1
		print("New Generation:" .. Neat.pool.generation)
end

function fai_neat_rankGlobally(Neat)
        local global = {}
        for s = 1,#Neat.pool.species do
                local species = Neat.pool.species[s]
                for g = 1,#species.genomes do
						species.genomes[g].evaluated = false
                        table.insert(global, species.genomes[g])
                end
        end
        table.sort(global, function (a,b)
                return (a.fitness < b.fitness)
        end)
       
        for g=1,#global do
                global[g].globalRank = g
        end
end

function fai_neat_sigmoid(Neat,x)
        return 2/(1+math.exp(-4.9*x))-1
end