/**
* Name: sheperd
* Based on the internal skeleton template. 
* Author: truonghm
* Tags: 
*/

model sheperd

global {
	int width <- 50;
	int height <- 50;
	float grove_pct <- 0.3;
	int number_of_goats <- 80;
	int number_of_goats_per_herd <- 10;
	float goat_eating_cap <- 0.08;
	float tree_growth_rate <- 0.1;
	
	float step <- 1 #week;
	
	list<pasture_cell> empty_cells;
	list<rgb> goat_colors <- [rgb(255,0,0), rgb(255,105,180), rgb(128,0,128), rgb(0,255,255), rgb(0,0,255), rgb(0,128,0), rgb(255,165,0), rgb(165,42,42)];
	init {
		empty_cells <- list(pasture_cell);
//		create grove number: width * height * grove_pct;
		create goat number: number_of_goats;
		loop c over: goat_colors {
		    
		    ask (number_of_goats_per_herd among goat) {
		    	color <- c;
		    	is_respectful <- flip(0.5);
		    }
		}
	}
}

grid pasture_cell height: 50 width: 50 neighbors: 4 {
//	rgb color <- #darkseagreen;
	float max_tree <- 1.0;
	float growth_rate <- rnd(tree_growth_rate);
	float tree max: max_tree;
	bool has_tree <- flip(0.3);
	init {
		if has_tree {
			tree <- 1.0;
			color <- rgb(0, 100, 0);
		} else {
			tree <- 0.0;
			color <- rgb(144, 238, 144);
		}
	}
	reflex grow_tree {
		if color != rgb(144, 238, 144) {
			color <- rgb(int(144 * (1 - tree)), int(238 - 138 * tree), int(144 * (1 - tree)));
			tree <- tree + growth_rate;
		}
	}
	list<pasture_cell> neighbors2  <- (self neighbors_at 2);
}

//species grove {
//	rgb color <- #darkgreen;
//  
//	aspect default {
//		draw circle(1) color: color;
//	}
//}

species goat {
    rgb color <- #beige;
    bool is_respectful <- true;
	pasture_cell my_cell <- one_of (pasture_cell) ;
	float eating_cap <- goat_eating_cap;
    init {
	location <- my_cell.location;
    }
		
    reflex basic_move when: my_cell.tree = 0 and current_date.month <= 10 {
	my_cell <- one_of (my_cell.neighbors2) ;
	location <- my_cell.location ;
    }
    
    // https://gama-platform.org/wiki/PredatorPrey_step3
	reflex eat when: my_cell.tree > 0 and current_date.month <= 10 { 
		float energy_transfer <- min([eating_cap, my_cell.tree]);
		my_cell.tree <- my_cell.tree - energy_transfer;
	}

    aspect default {
        draw circle(0.8) color: color;
    }
}

experiment sheperd type: gui {
	output {
		monitor "Current month" value: current_date.month;
		display grid {
			grid pasture_cell;
//			species grove;
			species goat;
			
		}
	}
}
