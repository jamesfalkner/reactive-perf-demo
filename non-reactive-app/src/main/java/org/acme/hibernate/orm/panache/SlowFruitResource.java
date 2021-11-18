package org.acme.hibernate.orm.panache;

import java.util.List;

import javax.enterprise.context.ApplicationScoped;
import javax.transaction.Transactional;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.Response;

import io.quarkus.panache.common.Sort;

@Path("fruits")
@ApplicationScoped
@Produces("application/json")
@Consumes("application/json")
public class SlowFruitResource {

    @GET
    public List<Fruit> get() {
        return Fruit.listAll(Sort.by("name"));
    }

    @GET
    @Path("{id}")
    public Fruit getSingle(@PathParam("id") Long id) {
        return Fruit.findById(id);
    }

    @POST
    @Transactional
    public Response create(Fruit fruit) {
        if (fruit == null || fruit.id != null) {
            throw new WebApplicationException("Id was invalidly set on request.", 422);
        }

        fruit.persist();
        return Response.ok().entity(fruit).build();
    }

}
